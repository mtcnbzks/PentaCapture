//
//  MotionService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 11.11.2025.
//

import Combine
import CoreMotion
import Foundation

struct DeviceOrientation {
  let pitch: Double
  let roll: Double
  let yaw: Double
  let gravity: CMAcceleration

  var pitchDegrees: Double { pitch * 180.0 / .pi }
  var rollDegrees: Double { roll * 180.0 / .pi }
  var yawDegrees: Double { yaw * 180.0 / .pi }

  /// Device tilt relative to ground (0° = horizontal, 90° = vertical)
  var tiltAngleDegrees: Double {
    let magnitude = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
    guard magnitude > 0 else { return 0 }
    return acos(-gravity.z / magnitude) * 180.0 / .pi
  }

  var isVerticalPosition: Bool {
    (60...120).contains(tiltAngleDegrees)
  }
}

enum MotionError: LocalizedError {
  case notAvailable
  case failedToStart

  var errorDescription: String? {
    switch self {
    case .notAvailable: "Hareket sensörleri kullanılamıyor"
    case .failedToStart: "Hareket takibi başlatılamadı"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .notAvailable: "Bu cihazda gyroscope veya ivmeölçer bulunamadı. Lütfen farklı bir cihaz kullanın."
    case .failedToStart: "Hareket sensörleri başlatılamadı. Lütfen uygulamayı yeniden başlatın."
    }
  }
}

/// Service for tracking device motion using CoreMotion
@MainActor
class MotionService: ObservableObject {
  // MARK: - Published Properties
  @Published var currentOrientation: DeviceOrientation?
  @Published var isTracking = false
  @Published var error: MotionError?

  // MARK: - Private Properties
  private let motionManager = CMMotionManager()
  private let updateInterval: TimeInterval = 1.0 / 60.0  // 60 Hz
  private var updateCount = 0

  // Publisher for orientation updates
  let orientationPublisher = PassthroughSubject<DeviceOrientation, Never>()

  // MARK: - Properties
  var isAvailable: Bool {
    motionManager.isDeviceMotionAvailable
  }

  // MARK: - Initialization
  nonisolated init() {
    // Per Apple SE-0327: Non-async initializers can be nonisolated
    // when they don't access actor-isolated state
    print("🎯 MotionService initialized")
    print("   Device motion available: \(motionManager.isDeviceMotionAvailable)")
  }

  // MARK: - Start/Stop
  func startTracking() {
    guard isAvailable else {
      print("❌ Device motion not available")
      error = .notAvailable
      return
    }

    guard !isTracking else {
      print("⚠️ Already tracking motion")
      return
    }

    print("🚀 Starting CoreMotion tracking...")

    // Configure motion manager
    motionManager.deviceMotionUpdateInterval = updateInterval

    // Use xArbitraryZVertical reference frame
    // This provides gravity-aligned coordinates (Z axis = vertical)
    // Per Apple docs: Best for measuring relative device orientation
    let referenceFrame = CMAttitudeReferenceFrame.xArbitraryZVertical

    // Start device motion updates
    motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) {
      [weak self] (motion, error) in
      guard let self = self else { return }

      if let error = error {
        print("❌ CoreMotion error: \(error.localizedDescription)")
        Task { @MainActor in
          self.error = .failedToStart
          self.isTracking = false
        }
        return
      }

      guard let motion = motion else { return }

      // Extract orientation from CMDeviceMotion
      let orientation = DeviceOrientation(
        pitch: motion.attitude.pitch,
        roll: motion.attitude.roll,
        yaw: motion.attitude.yaw,
        gravity: motion.gravity
      )

      Task { @MainActor in
        self.currentOrientation = orientation
        self.orientationPublisher.send(orientation)

        // Log periodically (every 60 updates = ~1 second)
        self.updateCount += 1
        if self.updateCount % 60 == 1 {
          print(
            "📐 Motion: P=\(String(format: "%.1f°", orientation.pitchDegrees)) R=\(String(format: "%.1f°", orientation.rollDegrees)) Y=\(String(format: "%.1f°", orientation.yawDegrees)) Tilt=\(String(format: "%.1f°", orientation.tiltAngleDegrees))"
          )
        }
      }
    }

    isTracking = true
    error = nil
    updateCount = 0

    print("✅ CoreMotion tracking started")
  }

  func stopTracking() {
    guard isTracking else { return }

    print("⏹️ Stopping CoreMotion tracking...")
    motionManager.stopDeviceMotionUpdates()
    isTracking = false
    currentOrientation = nil

    print("✅ CoreMotion tracking stopped")
  }

  // MARK: - Utility Methods

  func isOrientationValid(for captureAngle: CaptureAngle, tolerance: Double = 15.0) -> Bool {
    guard let orientation = currentOrientation else { return false }
    let tilt = orientation.tiltAngleDegrees

    switch captureAngle {
    case .frontFace, .rightProfile, .leftProfile:
      return abs(tilt) <= tolerance
    case .vertex:
      return abs(tilt - 90.0) <= (tolerance + 5.0)
    case .donorArea:
      return (50...100).contains(tilt)
    }
  }

  func getOrientationFeedback(for captureAngle: CaptureAngle) -> String? {
    guard let orientation = currentOrientation else { return "Telefon açısı ölçülemiyor" }
    let tilt = orientation.tiltAngleDegrees

    switch captureAngle {
    case .frontFace, .rightProfile, .leftProfile:
      if tilt > 30 { return "Telefonu daha yatay tutun" }
      if tilt > 15 { return "Telefonu biraz daha yatay tutun" }
      return nil
    case .vertex:
      let error = tilt - 90.0
      if abs(error) <= 15 { return nil }
      return error < -15 ? "Telefonu daha dik tutun" : "Telefonu başınızın tam üstüne getirin"
    case .donorArea:
      if tilt < 50 { return "Telefonu daha dik tutun" }
      if tilt > 100 { return "Telefonu biraz daha yatay tutun" }
      return nil
    }
  }

  // MARK: - Cleanup
  deinit {
    // Note: deinit is nonisolated, so we can't check @MainActor properties
    // Always stop motion updates on cleanup to be safe
    motionManager.stopDeviceMotionUpdates()
  }
}
