//
//  FaceTrackingService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import ARKit
import Combine
import CoreImage
import UIKit
import simd

struct HeadPose: Equatable {
  let yaw: Double
  let pitch: Double
  let roll: Double
  let transform: simd_float4x4
  let position: simd_float3

  var yawDegrees: Double { yaw * 180.0 / .pi }
  var pitchDegrees: Double { pitch * 180.0 / .pi }
  var rollDegrees: Double { roll * 180.0 / .pi }

  /// Normalized center offset (0.0 = center)
  var centerOffset: CGPoint {
    CGPoint(x: CGFloat(position.x / 0.15), y: CGFloat(position.y / 0.2))
  }
}

enum FaceTrackingError: LocalizedError {
  case notSupported
  case sessionFailed
  case noFaceDetected

  var errorDescription: String? {
    switch self {
    case .notSupported: "Bu cihazda yüz takibi desteklenmiyor"
    case .sessionFailed: "ARSession başlatılamadı"
    case .noFaceDetected: "Yüz tespit edilemedi"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .notSupported:
      "PentaCapture, iPhone X veya daha yeni bir cihaz gerektirir. Lütfen TrueDepth kamerası olan bir cihaz kullanın."
    case .sessionFailed:
      "Uygulamayı yeniden başlatmayı deneyin. Sorun devam ederse lütfen cihazınızı yeniden başlatın."
    case .noFaceDetected:
      "Yüzünüzün kamera görüş alanında olduğundan ve ortamın yeterince aydınlık olduğundan emin olun."
    }
  }
}

/// ARKit tabanlı yüz takip servisi
@MainActor
class FaceTrackingService: NSObject, ObservableObject {
  @Published var isTracking = false
  @Published var currentHeadPose: HeadPose?
  @Published var error: FaceTrackingError?
  @Published var trackingState: String = "Not Started"

  nonisolated(unsafe) let isSupported: Bool
  let arSession = ARSession()  // Public - ARSCNView için gerekli
  private var frameCount = 0

  // Idle timer management - auto-enable after 2 minutes
  private var idleTimerTask: Task<Void, Never>?

  override nonisolated init() {
    self.isSupported = ARFaceTrackingConfiguration.isSupported
    super.init()

    Task { @MainActor in
      print("🎯 FaceTrackingService initialized")
      print("   ARKit supported: \(self.isSupported)")
      print("   Device: \(UIDevice.current.model)")
    }
  }

  func startTracking() {
    guard isSupported else {
      print("❌ ARKit not supported on this device")
      error = .notSupported
      return
    }

    guard !isTracking else {
      print("⚠️ Already tracking")
      // Make sure idle timer is disabled even if already tracking
      UIApplication.shared.isIdleTimerDisabled = true
      return
    }

    print("🚀 Starting ARKit Face Tracking...")

    let configuration = ARFaceTrackingConfiguration()
    configuration.isLightEstimationEnabled = false
    configuration.maximumNumberOfTrackedFaces = 1
    // CRITICAL: Use .camera alignment for device-relative face orientation
    // This makes face angles independent of phone tilt (gravity)
    configuration.worldAlignment = .camera

    print("📋 Configuration:")
    print("   - worldAlignment: .camera (device-relative)")
    print("   - maxFaces: 1")

    arSession.delegate = self
    arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])

    isTracking = true
    error = nil
    frameCount = 0
    trackingState = "Starting..."

    // Disable idle timer to keep screen on during ARKit tracking
    UIApplication.shared.isIdleTimerDisabled = true
    print("🔆 Screen idle timer disabled - screen will stay on")

    // Auto-enable idle timer after 2 minutes
    scheduleIdleTimerReenable()

    print("✅ ARSession started")
  }

  func stopTracking() {
    guard isTracking else {
      // Re-enable idle timer even if not tracking
      UIApplication.shared.isIdleTimerDisabled = false
      return
    }

    print("⏹️ Stopping ARKit Face Tracking...")
    arSession.pause()
    isTracking = false
    currentHeadPose = nil

    // Cancel any pending idle timer re-enable
    cancelIdleTimerReenable()
    // Re-enable idle timer to allow screen to sleep
    UIApplication.shared.isIdleTimerDisabled = false
    print("🌙 Screen idle timer re-enabled - screen can sleep normally")
  }

  // MARK: - Idle Timer Management
  private func scheduleIdleTimerReenable() {
    // Cancel any existing task
    cancelIdleTimerReenable()

    print("⏱️ Scheduling idle timer re-enable in 2 minutes")
    idleTimerTask = Task { @MainActor in
      // Wait 2 minutes (120 seconds)
      try? await Task.sleep(nanoseconds: 120_000_000_000)

      // Check if task was cancelled
      guard !Task.isCancelled else {
        print("⏱️ Idle timer re-enable cancelled")
        return
      }

      // Re-enable idle timer after 2 minutes
      UIApplication.shared.isIdleTimerDisabled = false
      print("🌙 Auto re-enabled idle timer after 2 minutes - screen can now sleep")
    }
  }

  private func cancelIdleTimerReenable() {
    idleTimerTask?.cancel()
    idleTimerTask = nil
  }

  // MARK: - High Resolution Capture (iOS 16+)

  /// Capture high-resolution photo directly from ARKit session
  /// This is the BEST approach: 0 latency, 0 race conditions, highest quality
  /// Per Apple WWDC 2022: Use captureHighResolutionFrame for still image capture
  @available(iOS 16.0, *)
  func captureHighResolutionPhoto() async throws -> UIImage {
    guard isSupported else {
      throw FaceTrackingError.notSupported
    }

    guard isTracking else {
      throw FaceTrackingError.sessionFailed
    }

    print("📸 [ARKit Capture] Requesting high-resolution frame...")
    let captureStartTime = Date()

    return try await withCheckedThrowingContinuation { continuation in
      arSession.captureHighResolutionFrame { [weak self] frame, error in
        let captureLatency = Date().timeIntervalSince(captureStartTime)
        print("📸 [ARKit Capture] Latency: \(String(format: "%.3f", captureLatency))s")

        if let error = error {
          let nsError = error as NSError

          // Handle specific ARKit capture errors
          if nsError.domain == "com.apple.arkit.error" {
            switch nsError.code {
            case 101:  // highResolutionFrameCaptureInProgress
              print("❌ [ARKit Capture] Previous capture still in progress")
              continuation.resume(throwing: FaceTrackingError.sessionFailed)
              return
            case 102:  // highResolutionFrameCaptureFailed
              print("❌ [ARKit Capture] Capture failed in pipeline")
              continuation.resume(throwing: FaceTrackingError.sessionFailed)
              return
            default:
              print("❌ [ARKit Capture] Unknown error: \(error.localizedDescription)")
              continuation.resume(throwing: error)
              return
            }
          }

          print("❌ [ARKit Capture] Error: \(error.localizedDescription)")
          continuation.resume(throwing: error)
          return
        }

        guard let frame = frame else {
          print("❌ [ARKit Capture] No frame returned")
          continuation.resume(throwing: FaceTrackingError.noFaceDetected)
          return
        }

        // Extract high-resolution captured image
        let pixelBuffer = frame.capturedImage

        // Get buffer dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("📸 [ARKit Capture] Captured frame: \(width)x\(height)")

        // Convert CVPixelBuffer to UIImage
        let processingStartTime = Date()
        guard let image = self?.convertPixelBufferToUIImage(pixelBuffer) else {
          print("❌ [ARKit Capture] Failed to convert pixel buffer to UIImage")
          continuation.resume(throwing: FaceTrackingError.sessionFailed)
          return
        }

        let processingTime = Date().timeIntervalSince(processingStartTime)
        print("📸 [ARKit Capture] Image conversion: \(String(format: "%.3f", processingTime))s")
        print("📸 [ARKit Capture] Final image size: \(image.size)")

        // Mirror horizontally to match preview (front camera)
        let mirroredImage = self?.mirrorImageHorizontally(image) ?? image
        print("✅ [ARKit Capture] High-res capture complete!")

        continuation.resume(returning: mirroredImage)
      }
    }
  }

  /// Check if high-resolution capture is available
  /// Per Apple docs: Requires iOS 16+ and active ARSession
  @available(iOS 16.0, *)
  var canCaptureHighResolution: Bool {
    return isSupported && isTracking
  }

  // MARK: - Image Conversion Helpers

  /// Convert CVPixelBuffer to UIImage with proper orientation
  /// Per Apple ARKit docs: "capturedImage pixel buffer is NOT adjusted for device orientation"
  /// ARKit always captures in landscape-right orientation, we need to rotate for portrait
  private func convertPixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
    // Lock the pixel buffer for reading
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    // Get buffer properties
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    print("📐 [ARKit Image] CVPixelBuffer (raw camera): \(width)x\(height) (landscape)")

    // Create CIImage from pixel buffer
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

    // Create CIContext for rendering (use Metal for better performance)
    let context = CIContext(options: [.useSoftwareRenderer: false])

    // Render to CGImage
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
      print("❌ Failed to create CGImage from CIImage")
      return nil
    }

    // CRITICAL: ARKit camera orientation handling
    // Per Apple Documentation: "capturedImage is NOT adjusted for device orientation"
    // ARKit captures in landscape orientation from front camera
    // For portrait UI with front camera, we need .leftMirrored
    //
    // Orientation chart for front camera:
    // .up = 0° (no rotation) - wrong for portrait
    // .right = 90° CCW - was upside down
    // .rightMirrored = 90° CCW + mirror - was upside down
    // .left = 90° CW (landscape → portrait correct direction)
    // .leftMirrored = 90° CW + mirror (CORRECT FOR FRONT CAMERA PORTRAIT)
    //
    // Why .leftMirrored?
    // - Front camera captures landscape-left naturally
    // - Need 90° CW rotation for portrait (.left)
    // - Need horizontal flip for mirror effect (Mirrored)

    print("📐 [ARKit Image] Applying .leftMirrored (portrait + mirror for front camera)")
    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
    print("📐 [ARKit Image] Final UIImage: \(image.size), orientation: .leftMirrored")

    return image
  }

  /// Mirror image horizontally - NO LONGER NEEDED
  /// Orientation .rightMirrored already handles mirroring
  private func mirrorImageHorizontally(_ image: UIImage) -> UIImage {
    // With .rightMirrored orientation, additional mirroring is not needed
    // Just return as-is
    print("✅ [ARKit Image] Skipping manual mirror (orientation already handles it)")
    return image
  }

  // Extract HeadPose from ARFaceAnchor
  // With worldAlignment = .camera, transform is already camera-relative
  nonisolated private func extractHeadPose(from faceAnchor: ARFaceAnchor) -> HeadPose {
    let eulerAngles = faceAnchor.transform.eulerAngles

    // Extract 3D position from transform matrix (column 3 = translation)
    let position = simd_float3(
      faceAnchor.transform.columns.3.x,
      faceAnchor.transform.columns.3.y,
      faceAnchor.transform.columns.3.z
    )

    // Axis mapping for front camera + .camera alignment:
    // - yaw (left/right turn) → eulerAngles.x (negated for mirror)
    // - pitch (up/down tilt) → eulerAngles.y
    // - roll (side-to-side tilt) → eulerAngles.z
    return HeadPose(
      yaw: -Double(eulerAngles.x),
      pitch: Double(eulerAngles.y),
      roll: Double(eulerAngles.z),
      transform: faceAnchor.transform,
      position: position
    )
  }
}

// MARK: - ARSessionDelegate
extension FaceTrackingService: ARSessionDelegate {
  nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
    Task { @MainActor in
      self.frameCount += 1

      // Log ilk 10 frame ve sonra her 30 frame'de bir
      let shouldLog = self.frameCount <= 10 || self.frameCount % 30 == 0

      if shouldLog {
        print("📹 Frame #\(self.frameCount) - Anchors: \(frame.anchors.count)")
      }
    }

    guard let faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
      Task { @MainActor in
        if self.frameCount <= 20 {
          print("⚠️ No face anchor in frame #\(self.frameCount)")
        }
        self.currentHeadPose = nil
        self.trackingState = "No Face Detected"
      }
      return
    }

    // With .camera worldAlignment, face is already in camera space
    // No need to pass camera transform - it's automatic!
    let headPose = extractHeadPose(from: faceAnchor)

    Task { @MainActor in
      self.currentHeadPose = headPose
      self.trackingState = faceAnchor.isTracked ? "Tracking" : "Not Tracked"

      // İlk face bulunduğunda log
      if self.frameCount <= 10 {
        print(
          "✅ Face found! Yaw: \(String(format: "%.1f°", headPose.yawDegrees)) Pitch: \(String(format: "%.1f°", headPose.pitchDegrees)) Roll: \(String(format: "%.1f°", headPose.rollDegrees))"
        )
      }
    }
  }

  nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    Task { @MainActor in
      let stateDescription: String
      let reasonDescription: String

      switch camera.trackingState {
      case .normal:
        stateDescription = "Normal ✅"
        reasonDescription = "Tracking is working properly"
      case .notAvailable:
        stateDescription = "Not Available ❌"
        reasonDescription = "Tracking is not available"
      case .limited(let reason):
        stateDescription = "Limited ⚠️"
        switch reason {
        case .initializing:
          reasonDescription = "Initializing..."
        case .relocalizing:
          reasonDescription = "Relocalizing..."
        case .excessiveMotion:
          reasonDescription = "Too much motion"
        case .insufficientFeatures:
          reasonDescription = "Not enough features"
        @unknown default:
          reasonDescription = "Unknown reason"
        }
      }

      self.trackingState = stateDescription
      print("📊 Tracking State: \(stateDescription) - \(reasonDescription)")
    }
  }

  nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
    print("❌ ARSession failed: \(error.localizedDescription)")

    Task { @MainActor in
      self.error = .sessionFailed
      self.isTracking = false
      self.trackingState = "Failed"
    }
  }

  nonisolated func sessionWasInterrupted(_ session: ARSession) {
    print("⏸️ ARSession interrupted")

    Task { @MainActor in
      self.isTracking = false
      self.trackingState = "Interrupted"
    }
  }

  nonisolated func sessionInterruptionEnded(_ session: ARSession) {
    print("▶️ ARSession interruption ended")

    Task { @MainActor in
      if self.isSupported {
        self.startTracking()
      }
    }
  }
}
