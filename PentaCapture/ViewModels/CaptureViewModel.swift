//
//  CaptureViewModel.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Combine
import Foundation
import SwiftUI
import UIKit

/// Main coordinator for the capture process
@MainActor
class CaptureViewModel: ObservableObject {
  // MARK: - Published Properties
  @Published var session: CaptureSession
  @Published var currentValidation: PoseValidation?
  @Published var isCountingDown = false
  @Published var countdownValue = 3
  @Published var isCapturing = false
  @Published var showSuccess = false
  @Published var errorMessage: String?

  // MARK: - Services
  nonisolated(unsafe) let cameraService: CameraService
  nonisolated(unsafe) let audioService: AudioFeedbackService
  nonisolated(unsafe) let storageService: StorageService
  nonisolated(unsafe) let faceTrackingService: FaceTrackingService  // ARKit Face Tracking (TrueDepth only)
  nonisolated(unsafe) let motionService: MotionService  // CoreMotion for device orientation

  // MARK: - Private Properties
  private var cancellables = Set<AnyCancellable>()
  private var validationStartTime: Date?
  private var validationLogCount = 0
  private var countdownTask: Task<Void, Never>?

  // Locked pose tracking for stricter countdown validation
  private var lockedPose: HeadPose?
  private let countdownMovementTolerance = 8.0  // degrees

  // MARK: - Initialization
  init(
    cameraService: CameraService = CameraService(),
    audioService: AudioFeedbackService = AudioFeedbackService(),
    storageService: StorageService = StorageService(),
    faceTrackingService: FaceTrackingService = FaceTrackingService(),
    motionService: MotionService = MotionService()
  ) {
    self.cameraService = cameraService
    self.audioService = audioService
    self.storageService = storageService
    self.faceTrackingService = faceTrackingService
    self.motionService = motionService
    self.session = CaptureSession()
  }

  private func setupBindings() {
    // Use ARKit for tracking, no need for camera frame processing
    // ARKit provides face tracking data directly through FaceTrackingService
    // We'll validate on a timer instead of per-frame

    // Setup validation timer (15 times per second)
    Timer.publish(every: 1.0 / 15.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self = self else { return }
        // Perform validation using current ARKit data
        Task {
          await self.performValidation(nil)
        }
      }
      .store(in: &cancellables)

    // Per Apple documentation: Handle app lifecycle to save battery
    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in
        print("📱 App will resign active - pausing capture")
        self?.pauseCapture()
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in
        print("📱 App became active - resuming capture")
        self?.resumeCapture()
      }
      .store(in: &cancellables)
  }

  // MARK: - Lifecycle
  func startCapture() {
    print("🎬 Starting capture session...")
    
    setupBindings()

    // Request authorizations if needed
    if !storageService.isAuthorized {
      storageService.requestAuthorization()
    }

    // Start tracking time for first angle
    session.startAngleCapture(for: session.currentAngle)

    // Start services
    audioService.startProximityFeedback()

    // Start CoreMotion for device orientation tracking
    if motionService.isAvailable {
      motionService.startTracking()
      print("✅ CoreMotion tracking started")
    } else {
      print("⚠️ CoreMotion not available on this device")
    }

    // Start ARKit Face Tracking (REQUIRED - TrueDepth only)
    // ARKit provides its own camera feed, no need for separate AVCaptureSession
    if faceTrackingService.isSupported {
      print("🚀 Starting ARKit-based capture (ARKit provides camera feed)")
      
      // Small delay to ensure camera permission is fully granted
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        guard let self = self else { return }
        
        self.faceTrackingService.startTracking()
        
        // Setup camera for photo capture but DON'T start session yet
        // We'll start it only when capturing to avoid conflict with ARKit
        if self.cameraService.isAuthorized {
          print("📸 Configuring camera for photo capture (will start only during capture)")
          self.cameraService.setupCaptureSession()
          // DON'T start the session here - ARKit is using the camera
        } else {
          print("⚠️ Camera not authorized yet, will setup when authorized")
        }
        
        print("✅ ARKit Face Tracking enabled (TrueDepth device)")
      }
    } else {
      print(
        "❌ ARKit Face Tracking not available - app requires TrueDepth camera (iPhone X or later)")
      // Fallback: Use regular camera without ARKit
      if !cameraService.isSessionRunning {
        if cameraService.isAuthorized {
          cameraService.setupCaptureSession()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.cameraService.startSession()
          }
        } else {
          print("⚠️ Camera not authorized, waiting for permission...")
        }
      } else {
        cameraService.startSession()
      }
    }

    // Reset for current angle
    resetValidationState()
  }

  func stopCapture() {
    print("🛑 Stopping capture...")

    // Cancel any ongoing operations
    countdownTask?.cancel()
    countdownTask = nil
    isCountingDown = false

    // Per Apple documentation: Stop services to save battery
    audioService.stopProximityFeedback()
    faceTrackingService.stopTracking()  // Stop ARKit Face Tracking
    motionService.stopTracking()  // Stop CoreMotion

    // Only stop camera session if it was actually running
    // (it shouldn't be running when using ARKit for preview)
    if cameraService.isSessionRunning {
      cameraService.stopSession()
    }

    // Clear bindings
    cancellables.removeAll()
  }

  // MARK: - Lifecycle Helpers

  func pauseCapture() {
    print("⏸️ Pausing capture")

    // Cancel countdown if active
    if isCountingDown {
      cancelCountdown()
    }

    // Pause without fully stopping - maintain state
    audioService.stopProximityFeedback()
    motionService.stopTracking()

    // Pause ARKit if it's being used
    if faceTrackingService.isSupported {
      faceTrackingService.stopTracking()
    } else {
      // Only stop camera session if not using ARKit
      cameraService.stopSession()
    }
  }

  func resumeCapture() {
    print("▶️ Resuming capture")

    // Resume if user hasn't explicitly stopped
    guard cameraService.isAuthorized else {
      print("❌ Cannot resume: not authorized")
      return
    }

    audioService.startProximityFeedback()

    // Resume CoreMotion
    if motionService.isAvailable {
      motionService.startTracking()
    }

    // Resume ARKit if supported (it will handle camera)
    if faceTrackingService.isSupported {
      faceTrackingService.startTracking()
      // Don't start camera session - ARKit is handling it
    } else {
      // Only start camera session if not using ARKit
      cameraService.startSession()
    }
  }

  // MARK: - Frame Processing (ARKit-based)
  private func performValidation(_ pixelBuffer: CVPixelBuffer?) async {
    // Only skip if actively capturing the photo, NOT during countdown
    guard !isCapturing else { return }
    let currentAngle = session.currentAngle

    // Log tracking state periodically
    validationLogCount += 1
    if validationLogCount % 30 == 1 {
      print("🔍 Validation #\(validationLogCount)")
      print("   Tracking: \(faceTrackingService.isTracking)")
      print("   State: \(faceTrackingService.trackingState)")
      print("   Has pose: \(faceTrackingService.currentHeadPose != nil)")
    }

    // İlk 3 açıda yüz ekranda olmalı, son 2 açıda yüz ekrandan çıkabilir
    let requiresFaceDetection = currentAngle == .frontFace || currentAngle == .rightProfile || currentAngle == .leftProfile
    
    // ARKit'ten yüz pozisyonu al
    guard let headPose = faceTrackingService.currentHeadPose else {
      // Yüz tespit edilemedi
      if validationLogCount % 30 == 1 {
        print("   ❌ No head pose from ARKit")
      }

      // Vertex ve donorArea için yüz tespit edilemese bile devam edebilir
      // (yüz frame'in dışında olabilir - bu normal)
      if !requiresFaceDetection {
        if validationLogCount % 30 == 1 {
          print("   ℹ️  No face detected but OK for \(currentAngle.title) - face can be off-screen")
        }
        
        // Device orientation (IMU) kullanarak validation
        let deviceOrientation = motionService.currentOrientation
        let devicePitch = deviceOrientation?.pitchDegrees ?? 0.0
        let pitchError = abs(devicePitch - currentAngle.targetPitch)
        
        // Device pitch'e göre validation durumu
        let orientationStatus: ValidationStatus
        if pitchError <= currentAngle.pitchTolerance {
          orientationStatus = .valid
        } else {
          let progress = max(0, 1.0 - (pitchError / (currentAngle.pitchTolerance * 2)))
          orientationStatus = progress < 0.3 ? .invalid : .adjusting(progress: progress)
        }
        
        if validationLogCount % 30 == 1 {
          print("   📱 Device pitch: \(String(format: "%.1f", devicePitch))° (target: \(String(format: "%.1f", currentAngle.targetPitch))°)")
        }
        
        let partialValidation = PoseValidation(
          orientationValidation: OrientationValidation(
            status: orientationStatus,
            currentPitch: devicePitch,
            targetPitch: currentAngle.targetPitch,
            pitchError: pitchError,
            currentYaw: nil,
            targetYaw: nil,
            yawError: nil
          ),
          detectionValidation: DetectionValidation(
            status: .valid,  // Face detection not required
            boundingBox: nil,
            size: 1.0,
            centerOffset: .zero,
            isDetected: false
          ),
          isStable: orientationStatus.isValid,
          stabilityDuration: orientationStatus.isValid ? 1.0 : 0.0
        )
        currentValidation = partialValidation
        return
      }

      // İlk 3 açıda yüz tespit edilemezse hata
      let failedValidation = PoseValidation(
        orientationValidation: OrientationValidation(
          status: .invalid,
          currentPitch: 0.0,
          targetPitch: currentAngle.targetPitch,
          pitchError: 999.0,
          currentYaw: nil,
          targetYaw: currentAngle.targetYaw,
          yawError: nil
        ),
        detectionValidation: DetectionValidation(
          status: .invalid,
          boundingBox: nil,
          size: 0.0,
          centerOffset: .zero,
          isDetected: false
        ),
        isStable: false,
        stabilityDuration: 0.0
      )
      currentValidation = failedValidation
      return
    }

    // Log pose data
    if validationLogCount % 30 == 1 {
      print(
        "   ✅ Pose: Y=\(String(format: "%.1f", headPose.yawDegrees))° P=\(String(format: "%.1f", headPose.pitchDegrees))° R=\(String(format: "%.1f", headPose.rollDegrees))°"
      )
    }

    // Pitch ve yaw değerlerini al
    let currentPitch = headPose.pitchDegrees
    let pitchError = currentPitch - currentAngle.targetPitch

    let currentYaw: Double? = currentAngle.targetYaw != nil ? headPose.yawDegrees : nil
    let yawError: Double?
    if let targetYaw = currentAngle.targetYaw, let currentYaw = currentYaw {
      yawError = currentYaw - targetYaw
    } else {
      yawError = nil
    }

    // Yüz merkez pozisyonu kontrolü
    let centerOffset = headPose.centerOffset
    let centerDistance = sqrt(centerOffset.x * centerOffset.x + centerOffset.y * centerOffset.y)

    // İlk 3 açıda (frontFace, rightProfile, leftProfile) yüz ekranda olmalı
    // Son 2 açıda (vertex, donorArea) yüz ekrandan çıkabilir
    let requiresFaceOnScreen = currentAngle == .frontFace || currentAngle == .rightProfile || currentAngle == .leftProfile
    
    let detectionStatus: ValidationStatus
    if requiresFaceOnScreen {
      // İlk 3 açı: Yüz merkezde olmalı
      let maxCenterDistance: CGFloat = currentAngle == .frontFace ? 0.5 : 0.7  // frontFace daha strict
      let isCentered = centerDistance <= maxCenterDistance
      
      if !isCentered {
        let centerProgress = max(0, 1.0 - Double(centerDistance / maxCenterDistance))
        detectionStatus = centerProgress < 0.3 ? .invalid : .adjusting(progress: centerProgress)
      } else {
        detectionStatus = .valid
      }
    } else {
      // Vertex ve donorArea: Yüz ekrandan çıkabilir, merkez kontrolü yok
      detectionStatus = .valid
    }

    let detectionValidation = DetectionValidation(
      status: detectionStatus,
      boundingBox: nil,
      size: 1.0,
      centerOffset: centerOffset,
      isDetected: true
    )

    // Orientation durumunu hesapla
    let orientationStatus: ValidationStatus
    if let targetYaw = currentAngle.targetYaw {
      orientationStatus = ValidationMetrics.determineOrientationStatusWithYaw(
        currentPitch: currentPitch,
        targetPitch: currentAngle.targetPitch,
        pitchTolerance: currentAngle.pitchTolerance,
        currentYaw: currentYaw,
        targetYaw: targetYaw,
        yawTolerance: currentAngle.yawTolerance
      )
    } else {
      orientationStatus = ValidationMetrics.determineOrientationStatus(
        currentAngle: currentPitch,
        targetAngle: currentAngle.targetPitch,
        tolerance: currentAngle.pitchTolerance
      )
    }

    let orientationValidation = OrientationValidation(
      status: orientationStatus,
      currentPitch: currentPitch,
      targetPitch: currentAngle.targetPitch,
      pitchError: pitchError,
      currentYaw: currentYaw,
      targetYaw: currentAngle.targetYaw,
      yawError: yawError
    )

    // Stabilite hesapla
    let now = Date()
    if orientationValidation.status.isValid && detectionValidation.status.isValid {
      if validationStartTime == nil {
        validationStartTime = now
      }
    } else {
      validationStartTime = nil
    }

    let stabilityDuration = validationStartTime.map { now.timeIntervalSince($0) } ?? 0.0
    let isStable = stabilityDuration >= 0.5

    let validation = PoseValidation(
      orientationValidation: orientationValidation,
      detectionValidation: detectionValidation,
      isStable: isStable,
      stabilityDuration: stabilityDuration
    )

    await MainActor.run {
      self.currentValidation = validation

      // Log validation results periodically
      if validationLogCount % 30 == 1 {
        print("   📊 Validation Results:")
        print("      Overall: \(validation.overallStatus)")
        print("      Orientation: \(orientationValidation.status)")
        print(
          "         Pitch: \(String(format: "%.1f", currentPitch))° (target: \(String(format: "%.1f", currentAngle.targetPitch))°, tolerance: ±\(String(format: "%.1f", currentAngle.pitchTolerance))°)"
        )
        print("         Pitch Error: \(String(format: "%.1f", abs(pitchError)))°")
        if let currentYaw = currentYaw, let targetYaw = currentAngle.targetYaw,
          let yawError = yawError
        {
          print(
            "         Yaw: \(String(format: "%.1f", currentYaw))° (target: \(String(format: "%.1f", targetYaw))°, tolerance: ±\(String(format: "%.1f", currentAngle.yawTolerance))°)"
          )
          print("         Yaw Error: \(String(format: "%.1f", abs(yawError)))°")
        }
        print("      Detection: \(detectionValidation.status)")
        print(
          "      Stable: \(isStable) (\(String(format: "%.2f", stabilityDuration))s / \(String(format: "%.1f", PoseValidation.requiredStabilityDuration))s)"
        )
        print("      Ready: \(validation.isReadyForCapture)")
      }

      // Countdown sırasında validasyon kaybedildiyse iptal et
      if isCountingDown && !validation.isReadyForCapture {
        print("⚠️ Validation lost during countdown - cancelling")
        cancelCountdown()
      }

      // Ses feedback'i ver
      if !isCountingDown {
        audioService.playFeedback(.proximity(progress: validation.progress))
      }

      // Hazırsa otomatik çekim başlat
      if validation.isReadyForCapture && !isCountingDown && !isCapturing {
        print("🎯 Ready for capture!")
        triggerAutoCapture()
      }
    }
  }

  // MARK: - Capture Flow
  private func triggerAutoCapture() {
    guard !isCountingDown && !isCapturing else {
      print("⚠️ Auto-capture blocked: isCountingDown=\(isCountingDown), isCapturing=\(isCapturing)")
      return
    }

    print("⏱️ Starting countdown...")
    isCountingDown = true
    audioService.playFeedback(.locked)

    // Lock the current pose for strict movement detection during countdown
    lockedPose = faceTrackingService.currentHeadPose
    if let pose = lockedPose {
      print(
        "🔒 Locked pose: Yaw=\(String(format: "%.1f", pose.yawDegrees))° Pitch=\(String(format: "%.1f", pose.pitchDegrees))°"
      )
    }

    // Countdown sequence
    countdownValue = 3
    print("⏱️ Countdown: \(countdownValue)")

    // Store countdown task so we can cancel it if needed
    countdownTask = Task { @MainActor in
      for count in (1...3).reversed() {
        // Check if task was cancelled
        if Task.isCancelled {
          print("⚠️ Countdown task cancelled")
          return
        }

        // Check validation before starting this countdown step
        if self.currentValidation?.isReadyForCapture != true {
          print("⚠️ Validation lost at countdown \(count) - aborting")
          self.isCountingDown = false
          self.lockedPose = nil
          self.audioService.playFeedback(.error)
          return
        }

        self.countdownValue = count
        print("⏱️ Countdown: \(count)")

        // Play audio for all countdown numbers
        self.audioService.playFeedback(.countdown(number: count))

        // No extra haptic here - countdown already provides haptic feedback

        // Sleep in smaller increments to check cancellation more frequently
        for _ in 0..<10 {
          // Check cancellation and validation every 100ms
          if Task.isCancelled {
            print("⚠️ Countdown task cancelled during sleep")
            return
          }

          if self.currentValidation?.isReadyForCapture != true {
            print("⚠️ Validation lost during countdown sleep - aborting")
            self.isCountingDown = false
            self.lockedPose = nil
            self.audioService.playFeedback(.error)
            return
          }

          // STRICT movement check during countdown
          if let locked = self.lockedPose, let current = self.faceTrackingService.currentHeadPose {
            let yawDiff = abs(current.yawDegrees - locked.yawDegrees)
            let pitchDiff = abs(current.pitchDegrees - locked.pitchDegrees)

            if yawDiff > self.countdownMovementTolerance
              || pitchDiff > self.countdownMovementTolerance
            {
              print(
                "⚠️ Excessive movement during countdown! Yaw: \(String(format: "%.1f", yawDiff))° Pitch: \(String(format: "%.1f", pitchDiff))°"
              )
              self.isCountingDown = false
              self.lockedPose = nil
              self.audioService.playFeedback(.error)
              return
            }
          }

          try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
        }
      }

      // Final check before capture
      if Task.isCancelled {
        print("⚠️ Countdown cancelled before capture")
        self.lockedPose = nil
        return
      }

      // Verify validation is STILL good before capturing
      if self.currentValidation?.isReadyForCapture != true {
        print("⚠️ Final validation check failed - aborting capture")
        self.isCountingDown = false
        self.lockedPose = nil
        self.audioService.playFeedback(.error)
        return
      }

      print("📸 Countdown complete, capturing photo...")
      await self.capturePhoto()

      // Clear locked pose after capture
      self.lockedPose = nil
    }
  }

  private func cancelCountdown() {
    guard isCountingDown else { return }

    print("🛑 Cancelling countdown...")
    countdownTask?.cancel()
    countdownTask = nil
    isCountingDown = false
    countdownValue = 3
    lockedPose = nil

    // Play error feedback
    audioService.playFeedback(.error)
  }

  func manualCapture() async {
    print("🖐️ Manual capture triggered")

    // For manual capture, we still want to ensure basic face detection
    // but we can be more lenient than auto-capture
    if currentValidation?.detectionValidation.isDetected == false {
      print("⚠️ Manual capture blocked: no face detected")
      errorMessage =
        "Yüz tespit edilemedi. Lütfen yüzünüzün kamera görüş alanında olduğundan emin olun."
      audioService.playFeedback(.error)
      return
    }

    await capturePhoto()
  }

  private func capturePhoto() async {
    guard !isCapturing else {
      print("⚠️ Capture blocked: already capturing")
      return
    }

    // CRITICAL: Final validation check before starting capture
    // This prevents capturing if face left frame after countdown started
    guard currentValidation?.isReadyForCapture == true else {
      print("⚠️ Capture aborted: validation not ready at capture start")
      isCountingDown = false
      audioService.playFeedback(.error)
      return
    }

    print("📸 Starting photo capture for angle: \(session.currentAngle.title)")
    isCapturing = true
    isCountingDown = false

    // If using ARKit, we need to coordinate camera access
    let wasUsingARKit = faceTrackingService.isSupported && faceTrackingService.isTracking

    do {
      // If ARKit is running, temporarily pause it and start camera session
      if wasUsingARKit {
        print("⏸️ Pausing ARKit to capture photo...")
        faceTrackingService.stopTracking()

        // Start camera session for capture
        if !cameraService.isSessionRunning {
          print("📸 Starting camera session for capture...")
          cameraService.startSession()

          // Wait for camera to warm up and stabilize
          try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        }
      }

      print("📸 Calling cameraService.capturePhoto()...")
      var image = try await cameraService.capturePhoto()
      print("✅ Photo captured successfully! Image size: \(image.size)")

      // If we paused ARKit, stop camera and resume ARKit
      if wasUsingARKit {
        print("⏹️ Stopping camera session...")
        cameraService.stopSession()

        print("▶️ Resuming ARKit...")
        faceTrackingService.startTracking()
      }

      // Rotate donor area photo 180° (phone is held upside down)
      if session.currentAngle == .donorArea {
        if let rotatedImage = image.rotated180() {
          image = rotatedImage
          print("🔄 Donor area photo rotated 180°")
        }
      }

      // Play success feedback
      audioService.playCaptureSequence()

      // IMPORTANT: Record attempt FIRST to calculate timeSpent
      // This updates the stats before we create metadata
      session.recordAttempt(for: session.currentAngle, successful: true)

      // Now create metadata with updated stats
      let metadata = createCaptureMetadata(
        for: session.currentAngle,
        imageSize: image.size,
        validation: currentValidation
      )

      // Create captured photo with metadata
      let photo = CapturedPhoto(
        angle: session.currentAngle,
        image: image,
        metadata: metadata
      )

      // Add to session
      session.addPhoto(photo)
      print(
        "✅ Photo added to session. Total photos: \(session.capturedPhotos.count)/\(CaptureAngle.allCases.count)"
      )

      // Brief success flash (very quick - for visual feedback only)
      showSuccess = true
      try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds - just a quick flash
      showSuccess = false

      isCapturing = false

      // Check if session is complete
      if session.isComplete {
        print("🎉 Session complete! Moving to review...")
        await handleSessionComplete()
      } else {
        print("➡️ Moving to next angle: \(session.currentAngle.title)")
        // Reset for next angle
        resetValidationState()
      }

    } catch {
      print("❌ Photo capture failed: \(error.localizedDescription)")

      // If we paused ARKit, make sure to resume it even on error
      if wasUsingARKit {
        print("🔄 Resuming ARKit after error...")
        if cameraService.isSessionRunning {
          cameraService.stopSession()
        }
        faceTrackingService.startTracking()
      }

      isCapturing = false
      isCountingDown = false
      errorMessage = "Fotoğraf çekimi başarısız: \(error.localizedDescription)"
      audioService.playFeedback(.error)
    }
  }

  // MARK: - Session Management
  private func resetValidationState() {
    print("🔄 Resetting validation state for angle: \(session.currentAngle.title)")

    // Start tracking time for this angle
    session.startAngleCapture(for: session.currentAngle)

    // Cancel any active countdown
    if isCountingDown {
      countdownTask?.cancel()
      countdownTask = nil
      isCountingDown = false
    }

    currentValidation = nil
    validationStartTime = nil
    countdownValue = 3
  }

  func retakeCurrentAngle() {
    print("🔄 Retaking current angle: \(session.currentAngle.title)")
    session.retakeAngle(session.currentAngle)
    resetValidationState()

    // Restart capture services
    startCapture()
  }

  func retakeAngle(_ angle: CaptureAngle) {
    print("🔄 Retaking angle: \(angle.title)")
    session.retakeAngle(angle)
    resetValidationState()

    // Restart capture services if not already running
    // Check ARKit first (it handles camera), then fall back to camera session
    let needsRestart =
      faceTrackingService.isSupported
      ? !faceTrackingService.isTracking : !cameraService.isSessionRunning

    if needsRestart {
      startCapture()
    }
  }

  func resetSession() {
    session.reset()
    resetValidationState()
  }

  private func handleSessionComplete() async {
    print("🎉 Handling session completion...")

    // Stop all services
    stopCapture()

    // No need to save locally - session is kept in memory
    // User will save to gallery from ReviewView if desired

    print("✅ Session complete and ready for review")
  }

  // MARK: - Manual Controls
  func skipToNextAngle() {
    guard let nextAngle = session.currentAngle.next else { return }
    session.currentAngle = nextAngle
    resetValidationState()
  }

  func goToPreviousAngle() {
    guard session.currentAngle.rawValue > 0 else { return }
    let previousAngle = CaptureAngle(rawValue: session.currentAngle.rawValue - 1)!
    session.currentAngle = previousAngle
    resetValidationState()
  }

  // MARK: - Helpers
  var progressPercentage: Int {
    Int(session.progress * 100)
  }

  var currentAngleNumber: Int {
    session.currentAngle.rawValue + 1
  }

  var totalAngles: Int {
    CaptureAngle.allCases.count
  }

  var canProceed: Bool {
    session.hasPhoto(for: session.currentAngle)
  }

  // MARK: - Metadata Creation

  /// Create capture metadata for ML model
  private func createCaptureMetadata(
    for angle: CaptureAngle,
    imageSize: CGSize,
    validation: PoseValidation?
  ) -> CaptureMetadata {
    // Get current device orientation
    let deviceOrientation = motionService.currentOrientation

    // Get current head pose
    let headPose = faceTrackingService.currentHeadPose

    // Calculate validation scores
    let validationScores: ValidationScores
    if let validation = validation {
      let pitchAccuracy: Double
      if let orientValidation = validation.orientationValidation as OrientationValidation? {
        let pitchError = abs(orientValidation.pitchError)
        let pitchTolerance = angle.pitchTolerance
        pitchAccuracy = max(0, 1.0 - (pitchError / (pitchTolerance * 2)))
      } else {
        pitchAccuracy = 0.5
      }

      let yawAccuracy: Double?
      if let targetYaw = angle.targetYaw,
        let orientValidation = validation.orientationValidation as OrientationValidation?,
        let yawError = orientValidation.yawError
      {
        let yawTolerance = angle.yawTolerance
        yawAccuracy = max(0, 1.0 - (abs(yawError) / (yawTolerance * 2)))
      } else {
        yawAccuracy = nil
      }

      let centeringAccuracy: Double
      if let detectionValidation = validation.detectionValidation as DetectionValidation? {
        let centerDistance = sqrt(
          detectionValidation.centerOffset.x * detectionValidation.centerOffset.x
            + detectionValidation.centerOffset.y * detectionValidation.centerOffset.y
        )
        centeringAccuracy = max(0, 1.0 - Double(centerDistance))
      } else {
        centeringAccuracy = 0.5
      }

      let stabilityScore =
        validation.isStable
        ? 1.0 : (validation.stabilityDuration / PoseValidation.requiredStabilityDuration)

      validationScores = ValidationScores(
        pitchAccuracy: pitchAccuracy,
        yawAccuracy: yawAccuracy,
        centeringAccuracy: centeringAccuracy,
        stabilityScore: stabilityScore
      )
    } else {
      // No validation available - use default values
      validationScores = ValidationScores(
        pitchAccuracy: 0.5,
        yawAccuracy: nil,
        centeringAccuracy: 0.5,
        stabilityScore: 0.5
      )
    }

    // Create device pose
    let devicePose = CaptureDevicePose(
      devicePitch: deviceOrientation?.pitchDegrees ?? 0,
      deviceRoll: deviceOrientation?.rollDegrees ?? 0,
      deviceYaw: deviceOrientation?.yawDegrees ?? 0,
      deviceTilt: deviceOrientation?.tiltAngleDegrees ?? 0,
      headPitch: headPose?.pitchDegrees,
      headYaw: headPose?.yawDegrees,
      headRoll: headPose?.rollDegrees
    )

    // Get attempt statistics
    let stats = session.angleStats[angle] ?? AngleCaptureStats(angle: angle)

    // Collect device information
    var systemInfo = utsname()
    uname(&systemInfo)
    let deviceIdentifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? "Unknown"
      }
    }

    // Get screen information - use native bounds for accurate device screen dimensions
    let screen = UIScreen.main
    let nativeBounds = screen.nativeBounds
    let nativeScale = screen.nativeScale

    let deviceInfo = DeviceInfo(
      deviceIdentifier: deviceIdentifier,
      iosVersion: UIDevice.current.systemVersion,
      screenWidth: Double(nativeBounds.width / nativeScale),  // Physical points
      screenHeight: Double(nativeBounds.height / nativeScale),  // Physical points
      screenScale: Double(nativeScale),
      hasTrueDepth: faceTrackingService.isSupported,
      cameraPosition: "front",
      appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    )

    // Log the stats we're using for metadata
    print("📊 Creating metadata for \(angle.title):")
    print("   Device: \(deviceInfo.deviceIdentifier)")
    print(
      "   Screen: \(String(format: "%.0fx%.0f", deviceInfo.screenWidth, deviceInfo.screenHeight)) pts @ \(String(format: "%.0f", deviceInfo.screenScale))x"
    )
    print("   Attempts: \(stats.attempts)")
    print("   Time spent: \(String(format: "%.2f", stats.totalTimeSpent))s")

    // Create full metadata
    return CaptureMetadata(
      captureId: UUID(),
      sessionId: session.sessionId,
      angle: angle,
      angleIndex: angle.rawValue,
      timestamp: Date(),
      validationScores: validationScores,
      devicePose: devicePose,
      imageSize: imageSize,
      attemptCount: stats.attempts,
      timeSpent: stats.totalTimeSpent,
      deviceInfo: deviceInfo  // Stored internally, exported at session level
    )
  }
}

// MARK: - UIImage Extension
extension UIImage {
  /// Rotate image 180 degrees
  func rotated180() -> UIImage? {
    guard let cgImage = self.cgImage else { return nil }

    let width = cgImage.width
    let height = cgImage.height

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
      )
    else { return nil }

    // Rotate 180 degrees
    context.translateBy(x: CGFloat(width), y: CGFloat(height))
    context.rotate(by: .pi)

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let rotatedCGImage = context.makeImage() else { return nil }

    return UIImage(cgImage: rotatedCGImage, scale: self.scale, orientation: self.imageOrientation)
  }
}
