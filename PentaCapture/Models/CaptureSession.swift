//
//  CaptureSession.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Combine
import Foundation
import SwiftUI
import UIKit

/// Validation scores captured at the moment of photo capture
struct ValidationScores: Codable {
  let pitchAccuracy: Double  // 0.0 to 1.0
  let yawAccuracy: Double?  // 0.0 to 1.0 (optional for some angles)
  let centeringAccuracy: Double  // 0.0 to 1.0
  let stabilityScore: Double  // 0.0 to 1.0
  let overallScore: Double  // 0.0 to 1.0 (average)

  init(
    pitchAccuracy: Double, yawAccuracy: Double? = nil, centeringAccuracy: Double,
    stabilityScore: Double
  ) {
    self.pitchAccuracy = pitchAccuracy
    self.yawAccuracy = yawAccuracy
    self.centeringAccuracy = centeringAccuracy
    self.stabilityScore = stabilityScore

    // Calculate overall score
    var components = [pitchAccuracy, centeringAccuracy, stabilityScore]
    if let yawAccuracy = yawAccuracy {
      components.append(yawAccuracy)
    }
    self.overallScore = components.reduce(0, +) / Double(components.count)
  }

  enum CodingKeys: String, CodingKey {
    case pitchAccuracy = "pitch_accuracy"
    case yawAccuracy = "yaw_accuracy"
    case centeringAccuracy = "centering_accuracy"
    case stabilityScore = "stability_score"
    case overallScore = "overall_score"
  }
}

/// Device pose at the moment of capture
struct CaptureDevicePose: Codable {
  let devicePitch: Double  // Device pitch in degrees
  let deviceRoll: Double  // Device roll in degrees
  let deviceYaw: Double  // Device yaw in degrees
  let deviceTilt: Double  // Device tilt angle (0-180°, from horizontal)
  let headPitch: Double?  // Face/head pitch in degrees (from ARKit)
  let headYaw: Double?  // Face/head yaw in degrees (from ARKit)
  let headRoll: Double?  // Face/head roll in degrees (from ARKit)

  enum CodingKeys: String, CodingKey {
    case devicePitch = "device_pitch"
    case deviceRoll = "device_roll"
    case deviceYaw = "device_yaw"
    case deviceTilt = "device_tilt"
    case headPitch = "head_pitch"
    case headYaw = "head_yaw"
    case headRoll = "head_roll"
  }
}

/// Device and camera information for ML analysis
struct DeviceInfo: Codable {
  let deviceIdentifier: String  // e.g. "iPhone15,2"
  let iosVersion: String  // e.g. "17.0"
  let screenWidth: Double  // Screen width in points
  let screenHeight: Double  // Screen height in points
  let screenScale: Double  // Screen scale factor (2x, 3x)
  let hasTrueDepth: Bool  // TrueDepth camera availability
  let cameraPosition: String  // "front" or "back"
  let appVersion: String  // App version

  enum CodingKeys: String, CodingKey {
    case deviceIdentifier = "device_identifier"
    case iosVersion = "ios_version"
    case screenWidth = "screen_width"
    case screenHeight = "screen_height"
    case screenScale = "screen_scale"
    case hasTrueDepth = "has_truedepth"
    case cameraPosition = "camera_position"
    case appVersion = "app_version"
  }
}

/// Extended metadata for ML model training
struct CaptureMetadata: Codable {
  let captureId: UUID
  let sessionId: UUID
  let angle: CaptureAngle  // Internal use only (not exported to JSON)
  let angleIndex: Int  // 0-4 (order in sequence)
  let timestamp: Date
  let validationScores: ValidationScores
  let devicePose: CaptureDevicePose
  let imageWidth: Double  // Image width in pixels
  let imageHeight: Double  // Image height in pixels
  let attemptCount: Int  // How many attempts for this angle
  let timeSpent: TimeInterval  // Time spent to capture this angle

  // Internal only - used to collect device info for session export
  var deviceInfo: DeviceInfo?

  enum CodingKeys: String, CodingKey {
    case captureId = "capture_id"
    case sessionId = "session_id"
    // Note: 'angle' is intentionally omitted - not exported to JSON
    case angleIndex = "angle_index"
    case timestamp
    case validationScores = "validation_scores"
    case devicePose = "device_pose"
    // Note: 'deviceInfo' is not exported here - it's at session level
    case imageWidth = "image_width"
    case imageHeight = "image_height"
    case attemptCount = "attempt_count"
    case timeSpent = "time_spent_seconds"
  }

  init(
    captureId: UUID, sessionId: UUID, angle: CaptureAngle, angleIndex: Int, timestamp: Date,
    validationScores: ValidationScores, devicePose: CaptureDevicePose, imageSize: CGSize,
    attemptCount: Int, timeSpent: TimeInterval, deviceInfo: DeviceInfo? = nil
  ) {
    self.captureId = captureId
    self.sessionId = sessionId
    self.angle = angle
    self.angleIndex = angleIndex
    self.timestamp = timestamp
    self.validationScores = validationScores
    self.devicePose = devicePose
    self.imageWidth = Double(imageSize.width)
    self.imageHeight = Double(imageSize.height)
    self.attemptCount = attemptCount
    self.timeSpent = timeSpent
    self.deviceInfo = deviceInfo
  }

  // Custom decoder - angle is derived from angleIndex
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    captureId = try container.decode(UUID.self, forKey: .captureId)
    sessionId = try container.decode(UUID.self, forKey: .sessionId)
    angleIndex = try container.decode(Int.self, forKey: .angleIndex)
    angle = CaptureAngle(rawValue: angleIndex) ?? .frontFace
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    validationScores = try container.decode(ValidationScores.self, forKey: .validationScores)
    devicePose = try container.decode(CaptureDevicePose.self, forKey: .devicePose)
    imageWidth = try container.decode(Double.self, forKey: .imageWidth)
    imageHeight = try container.decode(Double.self, forKey: .imageHeight)
    attemptCount = try container.decode(Int.self, forKey: .attemptCount)
    timeSpent = try container.decode(TimeInterval.self, forKey: .timeSpent)
    deviceInfo = nil  // Not decoded from individual photo metadata
  }

  // Custom encoder - angle and deviceInfo are not exported to JSON
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(captureId, forKey: .captureId)
    try container.encode(sessionId, forKey: .sessionId)
    try container.encode(angleIndex, forKey: .angleIndex)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(validationScores, forKey: .validationScores)
    try container.encode(devicePose, forKey: .devicePose)
    try container.encode(imageWidth, forKey: .imageWidth)
    try container.encode(imageHeight, forKey: .imageHeight)
    try container.encode(attemptCount, forKey: .attemptCount)
    try container.encode(timeSpent, forKey: .timeSpent)
    // deviceInfo is NOT encoded here - it's at session level
  }
}

/// Represents a single captured photo with metadata
struct CapturedPhoto: Identifiable, Codable {
  let id: UUID
  let angle: CaptureAngle
  let timestamp: Date
  let imageData: Data
  let metadata: CaptureMetadata?  // Extended metadata for ML

  init(
    id: UUID = UUID(), angle: CaptureAngle, timestamp: Date = Date(), image: UIImage,
    metadata: CaptureMetadata? = nil
  ) {
    self.id = id
    self.angle = angle
    self.timestamp = timestamp
    self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
    self.metadata = metadata
  }

  /// Get UIImage from stored data
  var image: UIImage? {
    UIImage(data: imageData)
  }

  enum CodingKeys: String, CodingKey {
    case id, angle, timestamp, imageData, metadata
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    let angleRawValue = try container.decode(Int.self, forKey: .angle)
    angle = CaptureAngle(rawValue: angleRawValue) ?? .frontFace
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    imageData = try container.decode(Data.self, forKey: .imageData)
    metadata = try container.decodeIfPresent(CaptureMetadata.self, forKey: .metadata)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(angle.rawValue, forKey: .angle)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(imageData, forKey: .imageData)
    try container.encodeIfPresent(metadata, forKey: .metadata)
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
    var stats = angleStats[angle] ?? AngleCaptureStats(angle: angle)
    stats.startTime = Date()
    angleStats[angle] = stats
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
      print(
        "⏱️ \(angle.title): Attempt #\(stats.attempts), Time: \(String(format: "%.1f", timeSpent))s")
    }

    // Mark as completed if successful
    if successful {
      stats.isCompleted = true
      stats.startTime = nil  // Clear start time
      print(
        "✅ \(angle.title) completed in \(String(format: "%.1f", stats.totalTimeSpent))s with \(stats.attempts) attempts"
      )
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

  // MARK: - ML Export

  /// Export session as JSON for ML model training/backend upload
  func exportAsJSON(includeImages: Bool = false) throws -> Data {
    let export = SessionExport(
      sessionId: sessionId,
      startTime: startTime,
      completionTime: Date(),
      photos: capturedPhotos,
      includeImages: includeImages
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    return try encoder.encode(export)
  }

  /// Export only metadata (without images) - for analytics/backend
  func exportMetadataJSON() throws -> Data {
    return try exportAsJSON(includeImages: false)
  }

  /// Save JSON export to file
  func saveJSONExport(to url: URL, includeImages: Bool = false) throws {
    let data = try exportAsJSON(includeImages: includeImages)
    try data.write(to: url)
    print("✅ Session exported to: \(url.path)")
  }
}

/// Session export structure for ML/Backend
struct SessionExport: Codable {
  let sessionId: UUID
  let deviceInfo: DeviceInfo  // Device info at session level (same for all photos)
  let startTime: Date
  let completionTime: Date
  let totalDuration: TimeInterval
  let photosMetadata: [CaptureMetadata]
  let images: [String: String]?  // angle.rawValue : base64EncodedImage (if includeImages)

  init(
    sessionId: UUID, startTime: Date, completionTime: Date, photos: [CapturedPhoto],
    includeImages: Bool
  ) {
    self.sessionId = sessionId
    self.startTime = startTime
    self.completionTime = completionTime
    self.totalDuration = completionTime.timeIntervalSince(startTime)

    // Extract device info from first photo (all photos have same device)
    self.deviceInfo =
      photos.first?.metadata?.deviceInfo
      ?? DeviceInfo(
        deviceIdentifier: "Unknown",
        iosVersion: "Unknown",
        screenWidth: 0,
        screenHeight: 0,
        screenScale: 1,
        hasTrueDepth: false,
        cameraPosition: "front",
        appVersion: "1.0"
      )

    // Extract metadata
    self.photosMetadata = photos.compactMap { $0.metadata }

    // Optionally include base64-encoded images
    if includeImages {
      var imagesDict: [String: String] = [:]
      for photo in photos {
        if let image = photo.image,
          let jpegData = image.jpegData(compressionQuality: 0.8)
        {
          let base64String = jpegData.base64EncodedString()
          imagesDict["\(photo.angle.rawValue)"] = base64String
        }
      }
      self.images = imagesDict
    } else {
      self.images = nil
    }
  }

  enum CodingKeys: String, CodingKey {
    case sessionId = "session_id"
    case deviceInfo = "device_info"
    case startTime = "start_time"
    case completionTime = "completion_time"
    case totalDuration = "total_duration_seconds"
    case photosMetadata = "photos_metadata"
    case images
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
