//
//  CameraService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import AVFoundation
import Combine
import UIKit

/// Errors that can occur during camera operations
enum CameraError: LocalizedError {
  case unauthorized
  case configurationFailed
  case captureSessionNotRunning
  case captureFailed
  case noCameraAvailable
  case insufficientLight
  case deviceTooUnstable

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      return "Kamera erişim izni gerekli"
    case .configurationFailed:
      return "Kamera yapılandırma hatası"
    case .captureSessionNotRunning:
      return "Kamera çalışmıyor"
    case .captureFailed:
      return "Fotoğraf çekimi başarısız"
    case .noCameraAvailable:
      return "Kamera bulunamadı"
    case .insufficientLight:
      return "Yetersiz ışık"
    case .deviceTooUnstable:
      return "Cihaz çok hareketli"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .unauthorized:
      return
        "PentaCapture'ın çalışması için kamera izni gereklidir. Lütfen Ayarlar > PentaCapture > Kamera bölümünden izin verin."
    case .configurationFailed:
      return
        "Kamera yapılandırılırken bir hata oluştu. Lütfen uygulamayı yeniden başlatın. Sorun devam ederse cihazınızı yeniden başlatın."
    case .captureSessionNotRunning:
      return "Kamera servisi başlatılamadı. Lütfen bir süre bekleyip tekrar deneyin."
    case .captureFailed:
      return "Fotoğraf çekimi sırasında bir hata oluştu. Lütfen tekrar deneyin."
    case .noCameraAvailable:
      return "Bu cihazda ön kamera bulunamadı. Lütfen farklı bir cihaz kullanın."
    case .insufficientLight:
      return "Fotoğraf çekimi için yeterli ışık yok. Lütfen daha aydınlık bir ortamda çekim yapın."
    case .deviceTooUnstable:
      return "Cihazınızı daha sabit tutun. Hareketli çekimler kalitesiz fotoğraflara neden olur."
    }
  }
}

/// Flash mode options
enum FlashMode: String, CaseIterable {
  case off = "Kapalı"
  case auto = "Otomatik"
  
  var icon: String {
    switch self {
    case .off: return "bolt.slash.fill"
    case .auto: return "bolt.badge.automatic.fill"
    }
  }
  
  var avFlashMode: AVCaptureDevice.FlashMode {
    switch self {
    case .off: return .off
    case .auto: return .auto
    }
  }
  
  /// Default flash mode for all capture angles
  static func defaultMode(for angle: CaptureAngle) -> FlashMode {
    return .off  // All angles: flash off by default
  }
}

/// Service responsible for managing camera operations
@MainActor
class CameraService: NSObject, ObservableObject {
  // MARK: - Published Properties
  @Published var isAuthorized = false
  @Published var isSessionRunning = false
  @Published var capturedImage: UIImage?
  @Published var error: CameraError?
  @Published var flashMode: FlashMode = .off  // Default: flash off

  // MARK: - Internal Properties
  let captureSession = AVCaptureSession()

  // MARK: - Private Properties
  private var videoDeviceInput: AVCaptureDeviceInput?
  private let photoOutput = AVCapturePhotoOutput()
  private let videoDataOutput = AVCaptureVideoDataOutput()

  private let sessionQueue = DispatchQueue(label: "com.pentacapture.camera.session")
  private let videoOutputQueue = DispatchQueue(label: "com.pentacapture.camera.videoOutput")

  private var videoDataOutputDelegate: VideoDataOutputDelegate?
  private var photoCaptureDelegate: PhotoCaptureDelegate?

  // Idle timer management - auto-enable after 2 minutes
  private var idleTimerTask: Task<Void, Never>?

  // Publisher for video frames
  let framePublisher = PassthroughSubject<CVPixelBuffer, Never>()

  // MARK: - Initialization
  override nonisolated init() {
    super.init()
    Task { @MainActor in
      self.checkAuthorization()
      self.setupNotifications()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Notifications
  @MainActor
  private func setupNotifications() {
    // Per Apple documentation: Handle session interruptions
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sessionWasInterrupted),
      name: .AVCaptureSessionWasInterrupted,
      object: captureSession
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sessionInterruptionEnded),
      name: .AVCaptureSessionInterruptionEnded,
      object: captureSession
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sessionRuntimeError),
      name: .AVCaptureSessionRuntimeError,
      object: captureSession
    )
  }

  @objc private func sessionWasInterrupted(notification: NSNotification) {
    print("⚠️ Camera session interrupted")
    if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey]
      as? AVCaptureSession.InterruptionReason
    {
      print("Interruption reason: \(reason.rawValue)")
    }
  }

  @objc private func sessionInterruptionEnded(notification: NSNotification) {
    print("✅ Camera session interruption ended")
  }

  @objc private func sessionRuntimeError(notification: NSNotification) {
    print("❌ Camera session runtime error")
    if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
      print("Error: \(error.localizedDescription)")

      Task { @MainActor in
        self.error = .configurationFailed

        // Try to restart session if possible
        if error.code != .mediaServicesWereReset {
          return
        }

        sessionQueue.async { [weak self] in
          guard let self = self else { return }
          self.captureSession.startRunning()
        }
      }
    }
  }

  // MARK: - Authorization
  @MainActor
  private func checkAuthorization() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      isAuthorized = true
      // Don't auto-setup session - let caller control when to setup
      // setupCaptureSession()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        Task { @MainActor in
          self?.isAuthorized = granted
          // Don't auto-setup after authorization
          // Camera session will be manually set up when needed
        }
      }
    case .denied, .restricted:
      isAuthorized = false
      error = .unauthorized
    @unknown default:
      isAuthorized = false
    }
  }

  // MARK: - Session Setup
  func setupCaptureSession() {
    print("🔧 Setting up camera session...")

    // Per Apple documentation: Setup should be done on a background queue
    sessionQueue.async { [weak self] in
      guard let self = self else { return }

      // Check if session is already configured
      guard self.videoDeviceInput == nil else {
        print("⚠️ Session already configured")
        return
      }

      do {
        try self.configureCaptureSession()
        Task { @MainActor in
          self.isSessionRunning = false
          print("✅ Camera configuration successful")
        }
      } catch {
        print("❌ Camera configuration failed: \(error)")
        Task { @MainActor in
          self.error = .configurationFailed
        }
      }
    }
  }

  private func configureCaptureSession() throws {
    // Per Apple documentation: Always wrap configuration in begin/commit
    captureSession.beginConfiguration()
    defer {
      captureSession.commitConfiguration()
      print("📝 Camera configuration committed")
    }

    // Set session preset for high quality photo capture
    captureSession.sessionPreset = .photo

    // Setup video input
    guard
      let videoDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .front)
    else {
      throw CameraError.noCameraAvailable
    }

    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

    guard captureSession.canAddInput(videoDeviceInput) else {
      throw CameraError.configurationFailed
    }

    captureSession.addInput(videoDeviceInput)
    self.videoDeviceInput = videoDeviceInput

    // Configure video device for optimal capture
    try configureVideoDevice(videoDevice)

    // Setup photo output
    guard captureSession.canAddOutput(photoOutput) else {
      throw CameraError.configurationFailed
    }

    captureSession.addOutput(photoOutput)

    // Configure photo output for JPEG with maximum quality
    photoOutput.isHighResolutionCaptureEnabled = true

    // QUALITY prioritization for maximum quality (iOS 13+)
    if #available(iOS 13.0, *) {
      photoOutput.maxPhotoQualityPrioritization = .quality  // Maximum quality!
      print("📸 Photo output configured for QUALITY prioritization with JPEG format")
    }

    // Enable video stabilization for better quality
    if let connection = photoOutput.connection(with: .video) {
      if connection.isVideoStabilizationSupported {
        connection.preferredVideoStabilizationMode = .auto
        print("📸 Video stabilization enabled for better quality")
      }
    }

    print("📸 Using JPEG format - Available codecs: \(photoOutput.availablePhotoCodecTypes.map { $0.rawValue })")

    // Setup video data output for frame processing
    guard captureSession.canAddOutput(videoDataOutput) else {
      throw CameraError.configurationFailed
    }

    captureSession.addOutput(videoDataOutput)

    videoDataOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]

    videoDataOutput.alwaysDiscardsLateVideoFrames = true

    let delegate = VideoDataOutputDelegate(framePublisher: framePublisher)
    videoDataOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
    self.videoDataOutputDelegate = delegate

    // Set video orientation
    if let connection = videoDataOutput.connection(with: .video) {
      if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
      if connection.isVideoMirroringSupported {
        connection.isVideoMirrored = true
      }
    }
  }

  private func configureVideoDevice(_ device: AVCaptureDevice) throws {
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    // Enable auto focus
    if device.isFocusModeSupported(.continuousAutoFocus) {
      device.focusMode = .continuousAutoFocus
    }

    // Enable auto exposure
    if device.isExposureModeSupported(.continuousAutoExposure) {
      device.exposureMode = .continuousAutoExposure
    }

    // Enable auto white balance
    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
      device.whiteBalanceMode = .continuousAutoWhiteBalance
    }

    // Enable low light boost for better quality in dark environments
    if device.isLowLightBoostSupported {
      device.automaticallyEnablesLowLightBoostWhenAvailable = true
      print("📸 Low light boost enabled for better quality in dark conditions")
    }

    // Set frame rate for better performance
    let desiredFrameRate = 30.0
    let formatDescription = device.activeFormat.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    print("Camera resolution: \(dimensions.width)x\(dimensions.height)")

    for range in device.activeFormat.videoSupportedFrameRateRanges {
      if range.maxFrameRate >= desiredFrameRate && range.minFrameRate <= desiredFrameRate {
        device.activeVideoMinFrameDuration = CMTimeMake(
          value: 1, timescale: Int32(desiredFrameRate))
        device.activeVideoMaxFrameDuration = CMTimeMake(
          value: 1, timescale: Int32(desiredFrameRate))
        break
      }
    }
  }

  // MARK: - Session Control
  func startSession() {
    guard isAuthorized else {
      print("❌ Cannot start session: not authorized")
      Task { @MainActor in
        self.error = .unauthorized
      }
      return
    }

    print("📹 Starting camera session...")

    sessionQueue.async { [weak self] in
      guard let self = self else { return }

      // Per Apple documentation: Check if session can run
      guard !self.captureSession.isRunning else {
        print("⚠️ Session already running")
        Task { @MainActor in
          self.isSessionRunning = true
          // Disable idle timer to keep screen on during capture
          UIApplication.shared.isIdleTimerDisabled = true
        }
        return
      }

      self.captureSession.startRunning()
      let isRunning = self.captureSession.isRunning
      print("✅ Camera session started (isRunning: \(isRunning))")

      Task { @MainActor in
        self.isSessionRunning = isRunning
        // Disable idle timer to keep screen on during capture
        UIApplication.shared.isIdleTimerDisabled = true
        print("🔆 Screen idle timer disabled - screen will stay on")
        
        // Auto-enable idle timer after 2 minutes
        self.scheduleIdleTimerReenable()
      }
    }
  }

  func stopSession() {
    print("⏹️ Stopping camera session...")

    sessionQueue.async { [weak self] in
      guard let self = self else { return }

      guard self.captureSession.isRunning else {
        print("⚠️ Session not running")
        Task { @MainActor in
          // Re-enable idle timer even if session wasn't running
          UIApplication.shared.isIdleTimerDisabled = false
        }
        return
      }

      // Per Apple documentation: Stop session to save battery
      self.captureSession.stopRunning()
      print("✅ Camera session stopped")

      Task { @MainActor in
        self.isSessionRunning = false
        // Cancel any pending idle timer re-enable
        self.cancelIdleTimerReenable()
        // Re-enable idle timer to allow screen to sleep
        UIApplication.shared.isIdleTimerDisabled = false
        print("🌙 Screen idle timer re-enabled - screen can sleep normally")
      }
    }
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

  // MARK: - Photo Capture
  func capturePhoto(forAngle angle: CaptureAngle? = nil) async throws -> UIImage {
    guard captureSession.isRunning else {
      print("❌ Capture session not running")
      throw CameraError.captureSessionNotRunning
    }

    print("📸 CameraService: Setting up photo capture...")
    
    // Lock focus and exposure for sharpest image
    // Per Apple documentation: Lock focus before capture to prevent blur
    if let device = videoDeviceInput?.device {
      try? device.lockForConfiguration()
      if device.isFocusModeSupported(.locked) {
        device.focusMode = .locked
        print("🔒 Focus locked for capture")
      }
      if device.isExposureModeSupported(.locked) {
        device.exposureMode = .locked
        print("🔒 Exposure locked for capture")
      }
      device.unlockForConfiguration()
    }

    return try await withCheckedThrowingContinuation { continuation in
      // Configure photo settings for JPEG format
      // Per Apple documentation: Default AVCapturePhotoSettings() uses JPEG format
      let settings = AVCapturePhotoSettings()
      print("📸 Using JPEG format for capture")
      
      // Configure flash mode - respect user's selection
      // User can toggle between .off and .auto
      settings.flashMode = flashMode.avFlashMode
      
      if let angle = angle {
        print("💡 Flash mode for \(angle.title): \(flashMode.rawValue)")
      }
      
      settings.isHighResolutionPhotoEnabled = true

      // QUALITY prioritization for maximum quality (iOS 13+)
      if #available(iOS 13.0, *) {
        settings.photoQualityPrioritization = .quality  // Maximum quality!
        print("📸 Using QUALITY prioritization")
      }

      // Enable auto stabilization for better quality
      if #available(iOS 13.0, *) {
        settings.isAutoStillImageStabilizationEnabled = true
        print("📸 Auto image stabilization enabled")
      }
      
      // Enable depth data if available (for better portrait mode, etc.)
      if photoOutput.isDepthDataDeliverySupported {
        settings.isDepthDataDeliveryEnabled = false  // Disabled for faster capture
      }
      
      // Enable portrait effects matte if available
      if #available(iOS 12.0, *) {
        if photoOutput.isPortraitEffectsMatteDeliverySupported {
          settings.isPortraitEffectsMatteDeliveryEnabled = false  // Disabled for faster capture
        }
      }

      print(
        "📸 CameraService: Creating photo capture delegate with settings: flash=\(settings.flashMode.rawValue), highRes=\(settings.isHighResolutionPhotoEnabled)"
      )

      // CRITICAL: Store delegate as instance variable to prevent garbage collection
      self.photoCaptureDelegate = PhotoCaptureDelegate { [weak self] result in
        print("📸 CameraService: Photo capture delegate callback received")
        
        // Re-enable continuous auto focus/exposure after capture
        if let device = self?.videoDeviceInput?.device {
          try? device.lockForConfiguration()
          if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
          }
          if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          }
          device.unlockForConfiguration()
          print("🔓 Focus/Exposure unlocked after capture")
        }
        
        continuation.resume(with: result)
        // Clear the delegate after use to free memory
        self?.photoCaptureDelegate = nil
      }

      print("📸 CameraService: Calling photoOutput.capturePhoto()...")
      photoOutput.capturePhoto(with: settings, delegate: self.photoCaptureDelegate!)
    }
  }

}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let completion: (Result<UIImage, Error>) -> Void

  init(completion: @escaping (Result<UIImage, Error>) -> Void) {
    self.completion = completion
    print("📸 PhotoCaptureDelegate: Initialized")
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    print("📸 PhotoCaptureDelegate: didFinishProcessingPhoto called")

    if let error = error {
      print("❌ PhotoCaptureDelegate: Error - \(error.localizedDescription)")
      completion(.failure(error))
      return
    }

    // Get image data from photo
    guard let imageData = photo.fileDataRepresentation() else {
      print("❌ PhotoCaptureDelegate: Failed to get image data")
      completion(.failure(CameraError.captureFailed))
      return
    }

    // Create UIImage from data (this respects EXIF orientation)
    guard var image = UIImage(data: imageData) else {
      print("❌ PhotoCaptureDelegate: Failed to create UIImage from data")
      completion(.failure(CameraError.captureFailed))
      return
    }

    // IMPORTANT: Mirror the image horizontally to match preview
    // Preview shows mirrored image (like a mirror), so we flip it horizontally
    image = self.mirrorImageHorizontally(image)

    print(
      "✅ PhotoCaptureDelegate: Created mirrored UIImage with size: \(image.size)"
    )
    completion(.success(image))
  }

  // Mirror image horizontally to match what user sees in preview
  // This flips the image along vertical axis (left becomes right, right becomes left)
  private func mirrorImageHorizontally(_ image: UIImage) -> UIImage {
    // Get the image size
    let size = image.size
    
    // Create a new image context with the same size
    UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else {
      print("⚠️ Failed to create graphics context, returning original image")
      return image
    }
    
    // Flip the context horizontally
    context.translateBy(x: size.width, y: 0)
    context.scaleBy(x: -1.0, y: 1.0)
    
    // Draw the image in the flipped context
    image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    
    // Get the new mirrored image
    let mirroredImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    guard let finalImage = mirroredImage else {
      print("⚠️ Failed to create mirrored image, returning original")
      return image
    }
    
    print("✅ Successfully mirrored image horizontally")
    return finalImage
  }
}

// MARK: - Video Data Output Delegate
private class VideoDataOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  let framePublisher: PassthroughSubject<CVPixelBuffer, Never>
  private var frameCount = 0
  private var lastLogTime = Date()

  init(framePublisher: PassthroughSubject<CVPixelBuffer, Never>) {
    self.framePublisher = framePublisher
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    frameCount += 1

    // Log every 30 frames (~1 second at 30fps) to avoid spam
    if frameCount % 30 == 0 {
      let now = Date()
      let fps = 30.0 / now.timeIntervalSince(lastLogTime)
      print("📹 Camera frames: \(frameCount) total, ~\(String(format: "%.1f", fps)) fps")
      lastLogTime = now
    }

    framePublisher.send(pixelBuffer)
  }
}
