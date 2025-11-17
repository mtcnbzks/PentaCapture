//
//  CameraService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

internal import AVFoundation
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
  
  // Capture readiness state (iOS 17+)
  // Per Apple WWDC 2023: Provides feedback on when photo output is ready for next capture
  @Published var captureReadiness: AVCapturePhotoOutput.CaptureReadiness = .sessionNotRunning

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
  
  // Readiness coordinator for capture readiness feedback (iOS 17+)
  private var readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator?

  // Idle timer management - auto-enable after 2 minutes
  private var idleTimerTask: Task<Void, Never>?

  // Publisher for video frames
  let framePublisher = PassthroughSubject<CVPixelBuffer, Never>()
  
  // MARK: - Performance Metrics
  // Track capture performance for optimization and debugging
  internal struct CaptureMetrics {
    var captureStartTime: Date?
    var captureEndTime: Date?
    var processingStartTime: Date?
    var processingEndTime: Date?
    var totalCaptureCount: Int = 0
    var successfulCaptureCount: Int = 0
    var failedCaptureCount: Int = 0
    
    var captureLatency: TimeInterval? {
      guard let start = captureStartTime, let end = captureEndTime else { return nil }
      return end.timeIntervalSince(start)
    }
    
    var processingTime: TimeInterval? {
      guard let start = processingStartTime, let end = processingEndTime else { return nil }
      return end.timeIntervalSince(start)
    }
    
    var successRate: Double {
      guard totalCaptureCount > 0 else { return 0 }
      return Double(successfulCaptureCount) / Double(totalCaptureCount)
    }
  }
  
  internal var performanceMetrics = CaptureMetrics()

  // MARK: - Initialization
  override nonisolated init() {
    super.init()
    Task { @MainActor in
      await self.checkAuthorization()
      self.setupNotifications()
    }
  }
  
  // Public method to re-check authorization (useful after user grants permission)
  func recheckAuthorization() async {
    await checkAuthorization()
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
  private func checkAuthorization() async {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      print("📹 Camera authorization: Authorized")
      isAuthorized = true
      // Don't auto-setup session - let caller control when to setup
      // setupCaptureSession()
    case .notDetermined:
      print("📹 Camera authorization: Not determined, requesting...")
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      print("📹 Camera authorization request result: \(granted)")
      isAuthorized = granted
      if !granted {
        error = .unauthorized
      }
      // Don't auto-setup after authorization
      // Camera session will be manually set up when needed
    case .denied, .restricted:
      print("📹 Camera authorization: Denied/Restricted")
      isAuthorized = false
      error = .unauthorized
    @unknown default:
      print("📹 Camera authorization: Unknown status")
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
    
    // Set session preset for photo capture
    // Per Apple documentation: Use .photo preset for high-quality still image capture
    if captureSession.canSetSessionPreset(.photo) {
      captureSession.sessionPreset = .photo
      print("📸 Session preset: .photo (high quality)")
    } else {
      // Fallback to high preset for older devices
      captureSession.sessionPreset = .high
      print("📸 Session preset: .high (fallback)")
    }
    
    // Log device information for debugging
    print("📱 Device Info:")
    print("   Model: \(UIDevice.current.model)")
    print("   System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    
    var systemInfo = utsname()
    uname(&systemInfo)
    let deviceIdentifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? "Unknown"
      }
    }
    print("   Device ID: \(deviceIdentifier)")

    // Setup video input
    guard
      let videoDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .front)
    else {
      throw CameraError.noCameraAvailable
    }
    
    print("📸 Camera Device: \(videoDevice.localizedName)")

    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

    guard captureSession.canAddInput(videoDeviceInput) else {
      throw CameraError.configurationFailed
    }

    captureSession.addInput(videoDeviceInput)
    self.videoDeviceInput = videoDeviceInput

    // Select optimal format BEFORE configuring device
    // Per Apple documentation: Choose format with highest resolution and best quality
    try selectOptimalFormat(for: videoDevice)

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
      print("📸 Photo output configured for QUALITY prioritization")
    }
    
    // Enable iOS 17+ Performance Features
    // Per Apple WWDC 2023: These features significantly improve capture performance
    if #available(iOS 17.0, *) {
      print("📸 iOS 17+ Performance Features:")
      
      // Zero Shutter Lag (iPhone 11 Pro and newer)
      // Per Apple WWDC 2023: Reduces capture latency significantly
      if photoOutput.isZeroShutterLagSupported {
        photoOutput.isZeroShutterLagEnabled = true
        print("   ✅ Zero Shutter Lag: ENABLED")
      } else {
        print("   ❌ Zero Shutter Lag: NOT SUPPORTED (requires iPhone 11 Pro or newer)")
      }
      
      // Responsive Capture (A12 Bionic and newer)
      // Per Apple WWDC 2023: Allows overlapping captures for faster shot-to-shot times
      // Note: Requires Zero Shutter Lag to be enabled
      if photoOutput.isResponsiveCaptureSupported && photoOutput.isZeroShutterLagEnabled {
        photoOutput.isResponsiveCaptureEnabled = true
        print("   ✅ Responsive Capture: ENABLED")
      } else if !photoOutput.isResponsiveCaptureSupported {
        print("   ❌ Responsive Capture: NOT SUPPORTED (requires A12 Bionic or newer)")
      } else {
        print("   ⚠️ Responsive Capture: DISABLED (requires Zero Shutter Lag)")
      }
      
      // Fast Capture Prioritization (A12 Bionic and newer)
      // Per Apple WWDC 2023: Adapts quality dynamically for consistent shot-to-shot times
      if photoOutput.isFastCapturePrioritizationSupported {
        photoOutput.isFastCapturePrioritizationEnabled = true
        print("   ✅ Fast Capture Prioritization: ENABLED")
      } else {
        print("   ❌ Fast Capture Prioritization: NOT SUPPORTED (requires A12 Bionic or newer)")
      }
    } else {
      print("📸 Running on iOS < 17: Performance features not available")
      print("   ℹ️  To get best performance, update to iOS 17 or later")
    }

    // Enable video stabilization for better quality
    if let connection = photoOutput.connection(with: .video) {
      if connection.isVideoStabilizationSupported {
        connection.preferredVideoStabilizationMode = .auto
        print("📸 Video stabilization enabled for better quality")
      }
    }

    print("📸 Photo output configuration complete")
    print("   - Format: JPEG")
    print("   - Available codecs: \(photoOutput.availablePhotoCodecTypes.map { $0.rawValue })")

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
    
    // Setup readiness coordinator (iOS 17+)
    // Per Apple WWDC 2023: Provides feedback on when photo output is ready for capture
    if #available(iOS 17.0, *) {
      readinessCoordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: photoOutput)
      readinessCoordinator?.delegate = self
      print("📸 Readiness coordinator configured for capture feedback")
    }
  }

  /// Select the optimal camera format for highest quality photo capture
  /// Per Apple WWDC 2023: Choose format based on resolution, codec, and quality support
  /// Implements robust fallback strategy for older devices (iPhone 11, etc.)
  private func selectOptimalFormat(for device: AVCaptureDevice) throws {
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    
    let formats = device.formats
    print("📸 Evaluating \(formats.count) available formats...")
    
    // Strategy 1: Find formats that support highest photo quality (iOS 13.0+)
    // Per Apple documentation: Look for isHighestPhotoQualitySupported
    let highQualityFormats = formats.filter { format in
      format.isHighestPhotoQualitySupported
    }
    
    print("📸 Found \(highQualityFormats.count) high quality formats")
    
    // Try to select from high quality formats first
    var selectedFormat: AVCaptureDevice.Format?
    
    if !highQualityFormats.isEmpty {
      // Among high quality formats, select the one with highest resolution
      let sortedFormats = highQualityFormats.sorted { format1, format2 in
        let dims1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
        let dims2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)
        let pixels1 = dims1.width * dims1.height
        let pixels2 = dims2.width * dims2.height
        return pixels1 > pixels2
      }
      selectedFormat = sortedFormats.first
      print("✅ Strategy 1 (High Quality): Selected format")
    } else {
      // Strategy 2: FALLBACK for older devices - select highest resolution format
      print("⚠️ No high quality format found, falling back to highest resolution format")
      let sortedAllFormats = formats.sorted { format1, format2 in
        let dims1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
        let dims2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)
        let pixels1 = dims1.width * dims1.height
        let pixels2 = dims2.width * dims2.height
        return pixels1 > pixels2
      }
      selectedFormat = sortedAllFormats.first
      print("✅ Strategy 2 (Fallback): Selected highest resolution format")
    }
    
    // Apply the selected format
    if let bestFormat = selectedFormat {
      device.activeFormat = bestFormat
      let dims = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
      print("📸 Selected format: \(dims.width)x\(dims.height)")
      print("   - Highest photo quality supported: \(bestFormat.isHighestPhotoQualitySupported)")
      
      // Log supported frame rates for this format
      if let frameRateRange = bestFormat.videoSupportedFrameRateRanges.first {
        print("   - Frame rate range: \(frameRateRange.minFrameRate)-\(frameRateRange.maxFrameRate) fps")
      }
    } else {
      // Strategy 3: Ultimate fallback - keep device default format
      // This should never happen, but defensive programming
      print("⚠️ Could not select custom format, using device default")
      let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
      print("📸 Using default format: \(dims.width)x\(dims.height)")
    }
  }
  
  private func configureVideoDevice(_ device: AVCaptureDevice) throws {
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    // Enable auto focus with subject area monitoring
    // Per Apple documentation: This improves focus accuracy
    if device.isFocusModeSupported(.continuousAutoFocus) {
      device.focusMode = .continuousAutoFocus
      // Enable subject area change monitoring for better focus accuracy
      device.isSubjectAreaChangeMonitoringEnabled = true
      print("📸 Continuous auto focus enabled with subject area monitoring")
    }

    // Enable auto exposure with subject area monitoring
    if device.isExposureModeSupported(.continuousAutoExposure) {
      device.exposureMode = .continuousAutoExposure
      print("📸 Continuous auto exposure enabled")
    }

    // Enable auto white balance
    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
      device.whiteBalanceMode = .continuousAutoWhiteBalance
      print("📸 Continuous auto white balance enabled")
    }

    // Enable low light boost for better quality in dark environments
    if device.isLowLightBoostSupported {
      device.automaticallyEnablesLowLightBoostWhenAvailable = true
      print("📸 Low light boost enabled for better quality in dark conditions")
    }

    // Set frame rate for better performance
    // Per Apple WWDC: 30fps is optimal for photo capture use cases
    let desiredFrameRate = 30.0
    let formatDescription = device.activeFormat.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    print("📸 Active camera resolution: \(dimensions.width)x\(dimensions.height)")

    for range in device.activeFormat.videoSupportedFrameRateRanges {
      if range.maxFrameRate >= desiredFrameRate && range.minFrameRate <= desiredFrameRate {
        device.activeVideoMinFrameDuration = CMTimeMake(
          value: 1, timescale: Int32(desiredFrameRate))
        device.activeVideoMaxFrameDuration = CMTimeMake(
          value: 1, timescale: Int32(desiredFrameRate))
        print("📸 Frame rate locked to \(desiredFrameRate) fps")
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

  // MARK: - Performance Logging
  /// Log performance metrics for debugging and optimization
  /// Per Apple best practices: Monitor capture performance to identify bottlenecks
  func logPerformanceMetrics() {
    let metrics = performanceMetrics
    
    print("📊 Camera Performance Metrics:")
    print("   Total captures: \(metrics.totalCaptureCount)")
    print("   Successful: \(metrics.successfulCaptureCount)")
    print("   Failed: \(metrics.failedCaptureCount)")
    print("   Success rate: \(String(format: "%.1f%%", metrics.successRate * 100))")
    
    if let latency = metrics.captureLatency {
      print("   Last capture latency: \(String(format: "%.3f", latency))s")
    }
    
    if let processingTime = metrics.processingTime {
      print("   Last processing time: \(String(format: "%.3f", processingTime))s")
    }
    
    // Log performance warnings
    if let latency = metrics.captureLatency, latency > 0.5 {
      print("⚠️ High capture latency detected: \(String(format: "%.3f", latency))s")
    }
    
    if let processingTime = metrics.processingTime, processingTime > 1.0 {
      print("⚠️ Long processing time detected: \(String(format: "%.3f", processingTime))s")
    }
    
    if metrics.successRate < 0.9 && metrics.totalCaptureCount >= 5 {
      print("⚠️ Low success rate: \(String(format: "%.1f%%", metrics.successRate * 100))")
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

    // Record capture start time for performance metrics
    performanceMetrics.captureStartTime = Date()
    performanceMetrics.totalCaptureCount += 1
    
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
      
      // Track this capture request with readiness coordinator (iOS 17+)
      // Per Apple WWDC 2023: This provides feedback on capture progress
      if #available(iOS 17.0, *) {
        readinessCoordinator?.startTrackingCaptureRequest(using: settings)
      }
      
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
      if #available(iOS 17.0, *) {
        self.photoCaptureDelegate = PhotoCaptureDelegate(
          completion: { [weak self] result in
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
          },
          readinessCoordinator: self.readinessCoordinator,
          cameraService: self
        )
      } else {
        self.photoCaptureDelegate = PhotoCaptureDelegate(
          completion: { [weak self] result in
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
          },
          cameraService: self
        )
      }

      print("📸 CameraService: Calling photoOutput.capturePhoto()...")
      photoOutput.capturePhoto(with: settings, delegate: self.photoCaptureDelegate!)
    }
  }

}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let completion: (Result<UIImage, Error>) -> Void
  private let readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator?
  private let cameraService: CameraService
  private let processingStartTime = Date()

  init(
    completion: @escaping (Result<UIImage, Error>) -> Void,
    readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator? = nil,
    cameraService: CameraService
  ) {
    self.completion = completion
    self.readinessCoordinator = readinessCoordinator
    self.cameraService = cameraService
    print("📸 PhotoCaptureDelegate: Initialized")
  }
  
  func photoOutput(
    _ output: AVCapturePhotoOutput,
    willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings
  ) {
    // Record when actual sensor capture begins
    Task { @MainActor in
      cameraService.performanceMetrics.processingStartTime = Date()
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    print("📸 PhotoCaptureDelegate: didFinishProcessingPhoto called")
    
    // Record processing end time
    Task { @MainActor in
      cameraService.performanceMetrics.processingEndTime = Date()
      cameraService.performanceMetrics.captureEndTime = Date()
    }
    
    // Stop tracking this capture request (iOS 17+)
    // Per Apple documentation: Use uniqueID to stop tracking
    if #available(iOS 17.0, *) {
      readinessCoordinator?.stopTrackingCaptureRequest(using: photo.resolvedSettings.uniqueID)
    }

    if let error = error {
      print("❌ PhotoCaptureDelegate: Error - \(error.localizedDescription)")
      Task { @MainActor in
        cameraService.performanceMetrics.failedCaptureCount += 1
        cameraService.logPerformanceMetrics()
      }
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
    
    // Record successful capture
    Task { @MainActor in
      cameraService.performanceMetrics.successfulCaptureCount += 1
      cameraService.logPerformanceMetrics()
    }
    
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

// MARK: - Readiness Coordinator Delegate (iOS 17+)
@available(iOS 17.0, *)
extension CameraService: AVCapturePhotoOutputReadinessCoordinatorDelegate {
  nonisolated func readinessCoordinator(
    _ coordinator: AVCapturePhotoOutputReadinessCoordinator,
    captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness
  ) {
    // Update readiness state on main actor
    // Per Apple WWDC 2023: Use this to update UI and control capture button state
    Task { @MainActor in
      self.captureReadiness = captureReadiness
      
      // Log readiness changes for debugging
      switch captureReadiness {
      case .ready:
        print("📸 Capture ready - can capture now")
      case .sessionNotRunning:
        print("⏹️ Capture not ready - session not running")
      case .notReadyMomentarily:
        print("⏳ Capture not ready momentarily - brief delay expected")
      case .notReadyWaitingForCapture:
        print("⏸️ Capture not ready - waiting for capture to complete")
      case .notReadyWaitingForProcessing:
        print("⚙️ Capture not ready - waiting for processing to complete")
      @unknown default:
        print("❓ Capture readiness: unknown state")
      }
    }
  }
}
