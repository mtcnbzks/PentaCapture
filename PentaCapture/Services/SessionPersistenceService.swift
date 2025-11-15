//
//  SessionPersistenceService.swift
//  PentaCapture
//
//  Session auto-save and restore service
//

import Combine
import Foundation
import UIKit

/// Manages auto-save and restore of capture sessions
class SessionPersistenceService: ObservableObject {
  // MARK: - Published Properties
  @Published var savedSessionMetadata: SessionMetadata?
  
  // MARK: - Constants
  private let sessionKey = "activeCaptureSession"
  private let sessionMetadataKey = "activeCaptureSessionMetadata"
  private let storageDirectory: URL
  
  // MARK: - Session Metadata
  struct SessionMetadata: Codable {
    let sessionId: UUID
    let startTime: Date
    let lastSavedTime: Date
    let currentAngleRawValue: Int
    let capturedCount: Int
    let totalCount: Int
    var isComplete: Bool
    
    var currentAngle: CaptureAngle {
      CaptureAngle(rawValue: currentAngleRawValue) ?? .frontFace
    }
    
    var progress: Double {
      Double(capturedCount) / Double(totalCount)
    }
    
    init(from session: CaptureSession) {
      self.sessionId = session.sessionId
      self.startTime = session.startTime
      self.lastSavedTime = Date()
      self.currentAngleRawValue = session.currentAngle.rawValue
      self.capturedCount = session.capturedCount
      self.totalCount = session.totalCount
      self.isComplete = session.isComplete
    }
  }
  
  // MARK: - Serializable Session
  struct SerializableSession: Codable {
    let sessionId: UUID
    let startTime: Date
    let currentAngleRawValue: Int
    let isComplete: Bool
    let photos: [CapturedPhoto]
    let angleStats: [Int: AngleCaptureStats]  // Key is angle rawValue
    
    init(from session: CaptureSession) {
      self.sessionId = session.sessionId
      self.startTime = session.startTime
      self.currentAngleRawValue = session.currentAngle.rawValue
      self.isComplete = session.isComplete
      self.photos = session.capturedPhotos
      
      // Convert angleStats dictionary with CaptureAngle key to Int key for Codable
      var statsDict: [Int: AngleCaptureStats] = [:]
      for (angle, stats) in session.angleStats {
        statsDict[angle.rawValue] = stats
      }
      self.angleStats = statsDict
    }
    
    func toCaptureSession() -> CaptureSession {
      // Convert Int keys back to CaptureAngle keys
      var restoredStats: [CaptureAngle: AngleCaptureStats] = [:]
      for (angleRawValue, stats) in angleStats {
        if let angle = CaptureAngle(rawValue: angleRawValue) {
          restoredStats[angle] = stats
        }
      }
      
      // Create CaptureSession with restored data
      return CaptureSession(
        sessionId: sessionId,
        startTime: startTime,
        currentAngle: CaptureAngle(rawValue: currentAngleRawValue) ?? .frontFace,
        capturedPhotos: photos,
        isComplete: isComplete,
        angleStats: restoredStats
      )
    }
  }
  
  // MARK: - Initialization
  init() {
    // Get Application Support directory for storing internal app state
    // Per Apple's recommendation: Use this directory for support files that your app
    // needs to operate but that you don't want to be openly visible
    self.storageDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    
    // Create directory if it doesn't exist
    try? FileManager.default.createDirectory(
      at: storageDirectory,
      withIntermediateDirectories: true
    )
    
    // Load saved session metadata on init
    self.savedSessionMetadata = loadSavedSessionMetadata()
  }
  
  // MARK: - Session File URL
  private var sessionFileURL: URL {
    storageDirectory.appendingPathComponent("active_session.json")
  }
  
  // MARK: - Save Methods
  
  /// Auto-save session to disk
  func saveSession(_ session: CaptureSession) {
    // Don't save if no photos captured yet
    guard session.capturedCount > 0 else {
      return
    }
    
    // Note: We save even if session is complete
    // User might want to continue from review screen
    
    do {
      // Create serializable version
      let serializable = SerializableSession(from: session)
      
      // Encode to JSON
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(serializable)
      
      // Write to file
      try data.write(to: sessionFileURL, options: .atomic)
      
      // Save metadata to UserDefaults for quick access
      let metadata = SessionMetadata(from: session)
      let metadataData = try encoder.encode(metadata)
      UserDefaults.standard.set(metadataData, forKey: sessionMetadataKey)
      
      // Update published property for reactive UI
      DispatchQueue.main.async { [weak self] in
        self?.savedSessionMetadata = metadata
      }
      
      print("💾 Session auto-saved: \(session.capturedCount)/\(session.totalCount) photos")
    } catch {
      print("❌ Failed to save session: \(error.localizedDescription)")
    }
  }
  
  /// Save session in background (non-blocking)
  func saveSessionAsync(_ session: CaptureSession) {
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.saveSession(session)
    }
  }
  
  // MARK: - Load Methods
  
  /// Check if there's a saved session available
  func hasSavedSession() -> Bool {
    return savedSessionMetadata != nil
  }
  
  /// Load metadata of saved session from disk (private helper)
  private func loadSavedSessionMetadata() -> SessionMetadata? {
    guard let metadataData = UserDefaults.standard.data(forKey: sessionMetadataKey) else {
      return nil
    }
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    do {
      let metadata = try decoder.decode(SessionMetadata.self, from: metadataData)
      // Only return if session is not complete and not too old (e.g., within 7 days)
      let daysSinceLastSave = Date().timeIntervalSince(metadata.lastSavedTime) / 86400
      if !metadata.isComplete && daysSinceLastSave < 7 {
        return metadata
      } else {
        // Clean up old/completed session
        clearSession()
        return nil
      }
    } catch {
      print("❌ Failed to decode session metadata: \(error.localizedDescription)")
      return nil
    }
  }
  
  /// Load saved session
  func loadSession() -> CaptureSession? {
    guard FileManager.default.fileExists(atPath: sessionFileURL.path) else {
      print("ℹ️ No saved session file found")
      return nil
    }
    
    do {
      // Read data from file
      let data = try Data(contentsOf: sessionFileURL)
      
      // Decode
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let serializable = try decoder.decode(SerializableSession.self, from: data)
      
      // Create session with restored data (preserves sessionId and startTime)
      let session = serializable.toCaptureSession()
      
      print("✅ Session restored: \(session.capturedCount)/\(session.totalCount) photos")
      print("   Session ID: \(session.sessionId)")
      print("   Started: \(session.startTime)")
      print("   Current angle: \(session.currentAngle.title)")
      
      return session
    } catch {
      print("❌ Failed to load session: \(error.localizedDescription)")
      // Clean up corrupted session file
      clearSession()
      return nil
    }
  }
  
  // MARK: - Clear Methods
  
  /// Clear saved session (called when session is complete or user starts fresh)
  func clearSession() {
    do {
      if FileManager.default.fileExists(atPath: sessionFileURL.path) {
        try FileManager.default.removeItem(at: sessionFileURL)
      }
      UserDefaults.standard.removeObject(forKey: sessionMetadataKey)
      
      // Update published property for reactive UI
      DispatchQueue.main.async { [weak self] in
        self?.savedSessionMetadata = nil
      }
      
      print("🧹 Saved session cleared")
    } catch {
      print("❌ Failed to clear session: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Helper Methods
  
  /// Format time interval for display (e.g., "2 dakika önce")
  static func formatTimeSince(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    let minutes = Int(interval / 60)
    let hours = Int(interval / 3600)
    let days = Int(interval / 86400)
    
    if days > 0 {
      return "\(days) gün önce"
    } else if hours > 0 {
      return "\(hours) saat önce"
    } else if minutes > 0 {
      return "\(minutes) dakika önce"
    } else {
      return "Az önce"
    }
  }
}

