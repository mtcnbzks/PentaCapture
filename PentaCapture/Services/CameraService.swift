//
//  CameraService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import AVFoundation
import UIKit
import Combine

/// Errors that can occur during camera operations
enum CameraError: LocalizedError {
    case unauthorized
    case configurationFailed
    case captureSessionNotRunning
    case captureFailed
    case noCameraAvailable
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Kamera erişim izni verilmedi. Lütfen Ayarlar'dan izin verin."
        case .configurationFailed:
            return "Kamera yapılandırılamadı."
        case .captureSessionNotRunning:
            return "Kamera çalışmıyor."
        case .captureFailed:
            return "Fotoğraf çekimi başarısız oldu."
        case .noCameraAvailable:
            return "Bu cihazda kullanılabilir kamera bulunamadı."
        }
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
        if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason {
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
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
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
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
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
        
        // Configure photo output for HEIC/HEVC capture
        photoOutput.isHighResolutionCaptureEnabled = true
        
        // Enable max quality for better HEIC results (iOS 13+)
        if #available(iOS 13.0, *) {
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        
        // Video stabilization
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        print("📸 Available photo codecs: \(photoOutput.availablePhotoCodecTypes.map { $0.rawValue })")
        
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
        
        // Set frame rate for better performance
        let desiredFrameRate = 30.0
        let formatDescription = device.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        print("Camera resolution: \(dimensions.width)x\(dimensions.height)")
        
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            if range.maxFrameRate >= desiredFrameRate && range.minFrameRate <= desiredFrameRate {
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
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
                }
                return
            }
            
            self.captureSession.startRunning()
            let isRunning = self.captureSession.isRunning
            print("✅ Camera session started (isRunning: \(isRunning))")
            
            Task { @MainActor in
                self.isSessionRunning = isRunning
            }
        }
    }
    
    func stopSession() {
        print("⏹️ Stopping camera session...")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.captureSession.isRunning else {
                print("⚠️ Session not running")
                return
            }
            
            // Per Apple documentation: Stop session to save battery
            self.captureSession.stopRunning()
            print("✅ Camera session stopped")
            
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async throws -> UIImage {
        guard captureSession.isRunning else {
            print("❌ Capture session not running")
            throw CameraError.captureSessionNotRunning
        }
        
        print("📸 CameraService: Setting up photo capture...")
        
        return try await withCheckedThrowingContinuation { continuation in
            // Configure photo settings for HEIC/HEVC capture
            let settings: AVCapturePhotoSettings
            
            // Directly capture in HEIC format (iOS 11+) for best quality and compression
            if #available(iOS 11.0, *),
               photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                // Use HEVC codec for HEIC format (50% smaller than JPEG, better quality)
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                print("📸 Using HEIC/HEVC format for capture")
            } else {
                // Fallback to default format for older devices
                settings = AVCapturePhotoSettings()
                print("⚠️ HEVC not available, using default format")
            }
            
            // Configure settings
            settings.flashMode = .off
            settings.isHighResolutionPhotoEnabled = true
            
            // Maximum quality prioritization (iOS 13+)
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .quality
            }
            
            // Auto still image stabilization
            if #available(iOS 13.0, *) {
                settings.isAutoStillImageStabilizationEnabled = true
            }
            
            print("📸 CameraService: Creating photo capture delegate with settings: flash=\(settings.flashMode.rawValue), highRes=\(settings.isHighResolutionPhotoEnabled)")
            
            // CRITICAL: Store delegate as instance variable to prevent garbage collection
            self.photoCaptureDelegate = PhotoCaptureDelegate { [weak self] result in
                print("📸 CameraService: Photo capture delegate callback received")
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
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 PhotoCaptureDelegate: didFinishProcessingPhoto called")
        
        if let error = error {
            print("❌ PhotoCaptureDelegate: Error - \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // CRITICAL: Use CGImageRepresentation to preserve orientation metadata
        // Per Apple docs: cgImageRepresentation() returns CGImage? directly
        // Front camera photos need proper orientation handling
        guard let cgImage = photo.cgImageRepresentation() else {
            print("❌ PhotoCaptureDelegate: Failed to get CGImage")
            completion(.failure(CameraError.captureFailed))
            return
        }
        
        // Get the correct orientation from photo metadata
        // Front camera is mirrored and may have different orientation
        let imageOrientation = self.getImageOrientation(from: photo)
        
        // Create UIImage with correct orientation
        let image = UIImage(cgImage: cgImage, 
                          scale: 1.0, 
                          orientation: imageOrientation)
        
        print("✅ PhotoCaptureDelegate: Created UIImage with orientation: \(imageOrientation.rawValue), size: \(image.size)")
        completion(.success(image))
    }
    
    // Convert AVCapturePhoto metadata orientation to UIImage orientation
    private func getImageOrientation(from photo: AVCapturePhoto) -> UIImage.Orientation {
        // Get orientation from photo metadata
        // For front camera in portrait mode, we typically need .leftMirrored
        guard let metadata = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32 else {
            // Default for front camera portrait: leftMirrored
            print("⚠️ No orientation metadata, using default .leftMirrored")
            return .leftMirrored
        }
        
        // Convert CGImagePropertyOrientation to UIImage.Orientation
        // Reference: https://developer.apple.com/documentation/imageio/cgimagepropertyorientation
        switch metadata {
        case 1: return .up
        case 2: return .upMirrored
        case 3: return .down
        case 4: return .downMirrored
        case 5: return .leftMirrored
        case 6: return .right
        case 7: return .rightMirrored
        case 8: return .left
        default:
            print("⚠️ Unknown orientation value: \(metadata), using .leftMirrored")
            return .leftMirrored
        }
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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

