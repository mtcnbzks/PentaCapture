//
//  CaptureSession.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Foundation
import UIKit
import SwiftUI
import Combine

/// Represents a single captured photo with metadata
struct CapturedPhoto: Identifiable, Codable {
    let id: UUID
    let angle: CaptureAngle
    let timestamp: Date
    let imageData: Data
    
    init(id: UUID = UUID(), angle: CaptureAngle, timestamp: Date = Date(), image: UIImage) {
        self.id = id
        self.angle = angle
        self.timestamp = timestamp
        self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
    }
    
    /// Get UIImage from stored data
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, angle, timestamp, imageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let angleRawValue = try container.decode(Int.self, forKey: .angle)
        angle = CaptureAngle(rawValue: angleRawValue) ?? .frontFace
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageData = try container.decode(Data.self, forKey: .imageData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(angle.rawValue, forKey: .angle)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(imageData, forKey: .imageData)
    }
}

/// Statistics for capturing a specific angle
struct AngleCaptureStats: Codable {
    let angle: CaptureAngle
    var attempts: Int = 0
    var startTime: Date?
    var totalTimeSpent: TimeInterval = 0
    var isCompleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case angle, attempts, startTime, totalTimeSpent, isCompleted
    }
    
    init(angle: CaptureAngle) {
        self.angle = angle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let angleRawValue = try container.decode(Int.self, forKey: .angle)
        angle = CaptureAngle(rawValue: angleRawValue) ?? .frontFace
        attempts = try container.decode(Int.self, forKey: .attempts)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        totalTimeSpent = try container.decode(TimeInterval.self, forKey: .totalTimeSpent)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(angle.rawValue, forKey: .angle)
        try container.encode(attempts, forKey: .attempts)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(totalTimeSpent, forKey: .totalTimeSpent)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

/// Manages the state of a capture session
class CaptureSession: ObservableObject {
    @Published var currentAngle: CaptureAngle
    @Published var capturedPhotos: [CapturedPhoto]
    @Published var isComplete: Bool
    @Published var angleStats: [CaptureAngle: AngleCaptureStats] = [:]
    
    let sessionId: UUID
    let startTime: Date
    
    init() {
        self.sessionId = UUID()
        self.startTime = Date()
        self.currentAngle = .frontFace
        self.capturedPhotos = []
        self.isComplete = false
        
        // Initialize stats for all angles
        CaptureAngle.allCases.forEach { angle in
            angleStats[angle] = AngleCaptureStats(angle: angle)
        }
    }
    
    /// Add a captured photo to the session
    func addPhoto(_ photo: CapturedPhoto) {
        // Prevent duplicate photos for the same angle
        // Remove any existing photo for this angle first
        capturedPhotos.removeAll { $0.angle == photo.angle }
        
        // Add the new photo
        capturedPhotos.append(photo)
        print("📸 Photo added for \(photo.angle.title). Total: \(capturedPhotos.count)")
        
        // Move to next angle or mark complete
        if let nextAngle = currentAngle.next {
            print("➡️ Moving to next angle: \(nextAngle.title)")
            currentAngle = nextAngle
        } else {
            print("✅ All angles captured! Session complete.")
            isComplete = true
        }
    }
    
    /// Check if a specific angle has been captured
    func hasPhoto(for angle: CaptureAngle) -> Bool {
        capturedPhotos.contains { $0.angle == angle }
    }
    
    /// Get photo for a specific angle
    func photo(for angle: CaptureAngle) -> CapturedPhoto? {
        capturedPhotos.first { $0.angle == angle }
    }
    
    /// Progress as percentage (0.0 to 1.0)
    var progress: Double {
        Double(capturedPhotos.count) / Double(CaptureAngle.allCases.count)
    }
    
    /// Number of photos captured
    var capturedCount: Int {
        capturedPhotos.count
    }
    
    /// Total number of photos needed
    var totalCount: Int {
        CaptureAngle.allCases.count
    }
    
    /// Reset session to start over
    func reset() {
        currentAngle = .frontFace
        capturedPhotos.removeAll()
        isComplete = false
        
        // Reset all stats
        CaptureAngle.allCases.forEach { angle in
            angleStats[angle] = AngleCaptureStats(angle: angle)
        }
    }
    
    /// Retake a specific angle
    func retakeAngle(_ angle: CaptureAngle) {
        capturedPhotos.removeAll { $0.angle == angle }
        currentAngle = angle
        isComplete = false
        
        // Reset stats for this angle
        angleStats[angle] = AngleCaptureStats(angle: angle)
    }
    
    // MARK: - Statistics Tracking
    
    /// Start tracking time for current angle
    func startAngleCapture(for angle: CaptureAngle) {
        angleStats[angle]?.startTime = Date()
        print("⏱️ Started tracking time for \(angle.title)")
    }
    
    /// Record a capture attempt (successful or not)
    func recordAttempt(for angle: CaptureAngle, successful: Bool) {
        guard var stats = angleStats[angle] else { return }
        
        // Increment attempt count
        stats.attempts += 1
        
        // Calculate time spent if we have a start time
        if let startTime = stats.startTime {
            let timeSpent = Date().timeIntervalSince(startTime)
            stats.totalTimeSpent += timeSpent
            print("⏱️ \(angle.title): Attempt #\(stats.attempts), Time: \(String(format: "%.1f", timeSpent))s")
        }
        
        // Mark as completed if successful
        if successful {
            stats.isCompleted = true
            stats.startTime = nil // Clear start time
            print("✅ \(angle.title) completed in \(String(format: "%.1f", stats.totalTimeSpent))s with \(stats.attempts) attempts")
        } else {
            // Restart timer for next attempt
            stats.startTime = Date()
        }
        
        angleStats[angle] = stats
    }
    
    /// Get statistics in a format suitable for ProgressHeatMap
    func getAngleStatsArray() -> [AngleStats] {
        return CaptureAngle.allCases.map { angle in
            let stats = angleStats[angle] ?? AngleCaptureStats(angle: angle)
            return AngleStats(
                angle: angle,
                attempts: stats.attempts,
                timeSpent: stats.totalTimeSpent,
                isCompleted: stats.isCompleted
            )
        }
    }
}

/// Statistics for ProgressHeatMap (matches the component's expected format)
struct AngleStats: Identifiable {
    let id = UUID()
    let angle: CaptureAngle
    var attempts: Int = 0
    var timeSpent: TimeInterval = 0
    var isCompleted: Bool = false
    
    var difficulty: Difficulty {
        if !isCompleted { return .pending }
        if timeSpent < 5 { return .easy }
        if timeSpent < 15 { return .medium }
        return .hard
    }
    
    enum Difficulty {
        case pending, easy, medium, hard
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }
        
        var label: String {
            switch self {
            case .pending: return "Bekliyor"
            case .easy: return "Kolay"
            case .medium: return "Orta"
            case .hard: return "Zor"
            }
        }
    }
}

