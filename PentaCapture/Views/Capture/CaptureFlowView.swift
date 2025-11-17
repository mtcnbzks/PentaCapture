//
//  CaptureFlowView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Main view orchestrating the 5-angle capture process
struct CaptureFlowView: View {
  @StateObject var viewModel: CaptureViewModel
  @State private var showingReview = false
  @State private var showingInstructions = true
  @State private var showingAngleTransition = false
  @State private var angleTransitionStartTime: Date?
  @State private var showingVideoInstruction = false
  @State private var currentVideoFileName: String?
  @State private var shownVideoAngles: Set<CaptureAngle> = []  // Track which angles have shown videos
  @AppStorage("debugMode") private var debugMode = false
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
      // Video instruction overlay (shown before specific angles)
      if showingVideoInstruction, let videoFileName = currentVideoFileName {
        VideoInstructionView(videoFileName: videoFileName) {
          // When video completes or is skipped
          withAnimation {
            showingVideoInstruction = false
            currentVideoFileName = nil
          }
          
          // Resume capture after video
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.resumeCapture()
          }
        }
        .zIndex(100)  // Ensure video is on top
      }
      
      // Camera preview
      if viewModel.faceTrackingService.isSupported {
        // Use ARKit camera feed when face tracking is available
        ARKitCameraPreviewView(faceTrackingService: viewModel.faceTrackingService)
          .ignoresSafeArea()
      } else {
        // Fallback to regular camera
        CameraPreviewView(cameraService: viewModel.cameraService)
          .ignoresSafeArea()
      }

      // Overlay UI
      VStack(spacing: 0) {
        // Top bar
        topBar
          .padding(.top, 8)
          .frame(maxWidth: .infinity)

        // Instructions for current angle - positioned near top
        if showingInstructions && !viewModel.isCountingDown {
          AngleInstructionView(angle: viewModel.session.currentAngle)
            .transition(.move(edge: .top).combined(with: .opacity))
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }

        Spacer()

        // Validation feedback with Proximity Indicator
        if let validation = viewModel.currentValidation,
          !viewModel.isCountingDown && !viewModel.showSuccess
        {
          VStack(spacing: 16) {
            // Large Proximity Indicator (Brief's key requirement)
            if validation.progress > 0.3 {
              ProximityIndicator(progress: validation.progress)
                .transition(.scale.combined(with: .opacity))
            }

            // Detailed validation feedback
            ValidationFeedbackView(validation: validation)
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }

        // Bottom controls (hidden during countdown)
        if !viewModel.isCountingDown {
          bottomControls
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }

      // Minimal center crosshair only (no big rectangle)
      if !viewModel.isCountingDown && !viewModel.showSuccess {
        CenterCrosshairView()
          .allowsHitTesting(false)
      }

      // Countdown overlay
      if viewModel.isCountingDown {
        CountdownWithMessageView(countdown: viewModel.countdownValue)
          .transition(.scale.combined(with: .opacity))
      }

      // Quick success flash (minimal - for speed)
      if viewModel.showSuccess {
        CompactSuccessView()
          .transition(.scale.combined(with: .opacity))
      }

      // Quick angle indicator (minimal - for speed)
      if showingAngleTransition {
        QuickAngleTransition(nextAngle: viewModel.session.currentAngle)
          .transition(.opacity)
      }

      // Debug overlay (top right) - only shown when debug mode is enabled
      if debugMode {
        VStack {
          HStack {
            Spacer()
            DebugOverlayView(
              trackingState: viewModel.faceTrackingService.trackingState,
              isTracking: viewModel.faceTrackingService.isTracking,
              headPose: viewModel.faceTrackingService.currentHeadPose
            )
            .padding()
          }
          Spacer()
        }
        .allowsHitTesting(false)  // Don't block touch events for buttons below
      }
    }
    .onAppear {
      // Small delay to ensure services and permissions are ready
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        viewModel.startCapture()
      }
    }
    .onDisappear {
      viewModel.stopCapture()
    }
    .alert(
      "Kamera İzni Gerekli", isPresented: .constant(viewModel.cameraService.error == .unauthorized)
    ) {
      Button("Ayarlara Git") {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(settingsURL)
        }
      }
      Button("İptal", role: .cancel) {
        dismiss()
      }
    } message: {
      Text(
        "PentaCapture'ın çalışması için kamera erişimi gereklidir. Lütfen Ayarlar'dan kamera iznini açın."
      )
    }
    .sheet(
      isPresented: $showingReview,
      onDismiss: {
        // When review sheet is dismissed, ensure camera restarts
        if !viewModel.cameraService.isSessionRunning {
          print("🔄 Review sheet dismissed - restarting camera")
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.startCapture()
          }
        }
      }
    ) {
      ReviewView(
        session: viewModel.session,
        storageService: viewModel.storageService,
        onRetake: { angle in
          showingReview = false
          // Delay to ensure sheet dismiss animation completes
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.retakeAngle(angle)
          }
        },
        onComplete: {
          showingReview = false
          dismiss()
        },
        onSaveToGallery: {}
      )
      .onAppear {
        // Ensure camera is fully stopped when review appears
        print("📱 Review opened - stopping all camera services")
        viewModel.stopCapture()
      }
    }
    .onAppear {
      // When view first appears (including restored sessions), check if we need to show video
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        checkAndShowVideoIfNeeded(for: viewModel.session.currentAngle)
      }
    }
    .onChange(of: viewModel.session.isComplete) { isComplete in
      if isComplete {
        // Pause capture before showing review
        viewModel.pauseCapture()

        // Small delay for smooth transition to review
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          showingReview = true
        }
      }
    }
    .onChange(of: viewModel.session.capturedCount) { newCount in
      // Show quick angle indicator when a photo is captured (except when session is complete)
      if newCount > 0 && !viewModel.session.isComplete {
        // Check if we need to show video instruction for next angle
        checkAndShowVideoIfNeeded(for: viewModel.session.currentAngle)
      }
    }
    .onChange(of: viewModel.session.currentAngle) { newAngle in
      // When angle changes (e.g., retake, session restored), check if we need to show video
      checkAndShowVideoIfNeeded(for: newAngle)
    }
    .onChange(of: viewModel.session.sessionId) { _ in
      // Session was reset - clear shown video tracking
      print("🔄 Session reset detected - clearing video tracking")
      shownVideoAngles.removeAll()
    }
    .onChange(of: viewModel.faceTrackingService.isTracking) { _ in
      // Yüz tespit durumu değiştiğinde transition'ı kontrol et
      if showingAngleTransition {
        checkAngleTransitionDismiss()
      }
    }
    .onChange(of: viewModel.faceTrackingService.currentHeadPose) { _ in
      // Yüz pozisyonu tespit edildiğinde transition'ı kontrol et
      if showingAngleTransition {
        checkAngleTransitionDismiss()
      }
    }
    .alert("Hata", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("Tamam") {
        viewModel.errorMessage = nil
      }
    } message: {
      if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
      }
    }
  }

  private var topBar: some View {
    HStack {
      // Close button with modern styling
      Button(action: {
        dismiss()
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 28))
          .foregroundColor(.white)
          .padding(8)
          .background(
            Circle()
              .fill(Color.black.opacity(0.3))
              .background(
                Circle()
                  .fill(.ultraThinMaterial)
              )
          )
          .shadow(color: .black.opacity(0.3), radius: 8)
      }

      Spacer()

      // Progress indicator (already modernized)
      ProgressIndicatorView(
        currentAngle: viewModel.session.currentAngle,
        capturedAngles: Set(viewModel.session.capturedPhotos.map { $0.angle })
      )

      Spacer()

      // Instructions toggle with modern styling
      Button(action: {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          showingInstructions.toggle()
        }
      }) {
        Image(systemName: showingInstructions ? "info.circle.fill" : "info.circle")
          .font(.system(size: 28))
          .foregroundColor(.white)
          .padding(8)
          .background(
            Circle()
              .fill(Color.black.opacity(0.3))
              .background(
                Circle()
                  .fill(.ultraThinMaterial)
              )
          )
          .shadow(color: .black.opacity(0.3), radius: 8)
      }
    }
    .padding()
  }

  private var bottomControls: some View {
    HStack(spacing: 30) {
      // Skip/Previous button with modern styling (with placeholder to maintain layout)
      Group {
        if viewModel.session.currentAngle.rawValue > 0 {
          Button(action: {
            viewModel.goToPreviousAngle()
          }) {
            Image(systemName: "chevron.left.circle.fill")
              .font(.system(size: 44))
              .foregroundColor(.white)
              .background(
                Circle()
                  .fill(Color.black.opacity(0.3))
                  .frame(width: 50, height: 50)
              )
              .shadow(color: .black.opacity(0.3), radius: 8)
          }
          .transition(.scale.combined(with: .opacity))
        } else {
          // Invisible placeholder to maintain flash button center alignment
          Color.clear
            .frame(width: 54, height: 54)
        }
      }

      Spacer()

      // Flash control button - center bottom
      FlashControlButton(cameraService: viewModel.cameraService)
        .transition(.scale.combined(with: .opacity))

      Spacer()

      // Review button with modern styling (with placeholder to maintain layout)
      Group {
        if !viewModel.session.capturedPhotos.isEmpty {
          Button(action: {
            showingReview = true
          }) {
            ZStack {
              // Background with glassmorphism
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .background(
                  RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                )
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.4), radius: 10)

              if let lastPhoto = viewModel.session.capturedPhotos.last,
                let thumbnail = lastPhoto.image
              {
                Image(uiImage: thumbnail)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 50, height: 50)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }

              // Badge with count
              Text("\(viewModel.session.capturedCount)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(6)
                .background(
                  Circle()
                    .fill(
                      LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                      )
                    )
                    .shadow(color: .red.opacity(0.5), radius: 4)
                )
                .offset(x: 20, y: -20)
            }
          }
          .transition(.scale.combined(with: .opacity))
        } else {
          // Invisible placeholder to maintain flash button center alignment
          Color.clear
            .frame(width: 54, height: 54)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 30)
  }
  
  // MARK: - Angle Transition Helpers
  
  /// Returns the video file name for a given angle, or nil if no video is needed
  private func videoFileNameForAngle(_ angle: CaptureAngle) -> String? {
    switch angle {
    case .vertex:
      return "KısaMOV.mov"
    case .donorArea:
      return "Uzun.mov"
    default:
      return nil
    }
  }
  
  /// Check if video instruction is needed for this angle and show it if not already shown
  private func checkAndShowVideoIfNeeded(for angle: CaptureAngle) {
    // Check if this angle needs a video
    guard let videoFileName = videoFileNameForAngle(angle) else {
      // No video needed, show normal transition
      if !showingVideoInstruction && !viewModel.session.isComplete {
        withAnimation {
          showingAngleTransition = true
          angleTransitionStartTime = Date()
        }
        checkAngleTransitionDismiss()
      }
      return
    }
    
    // Check if we already showed video for this angle
    if shownVideoAngles.contains(angle) {
      print("📹 Video already shown for \(angle.title), skipping")
      return
    }
    
    // Show video instruction
    print("📹 Showing video instruction for \(angle.title): \(videoFileName)")
    
    // Mark as shown
    shownVideoAngles.insert(angle)
    
    // Pause capture while showing video
    viewModel.pauseCapture()
    
    // Show video after a brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation {
        currentVideoFileName = videoFileName
        showingVideoInstruction = true
      }
    }
  }
  
  /// Angle transition'ı kapatmak için kontrol eder
  /// Minimum 1sn bekler ve eğer sonraki açı yüz gerektiriyorsa yüz tespit edilmesini bekler
  private func checkAngleTransitionDismiss() {
    guard showingAngleTransition else { return }
    
    // Minimum 1 saniye geçmiş mi?
    guard let startTime = angleTransitionStartTime,
          Date().timeIntervalSince(startTime) >= 1.0 else {
      // Henüz 1 saniye geçmemiş, 0.2 saniye sonra tekrar kontrol et
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        checkAngleTransitionDismiss()
      }
      return
    }
    
    // Sonraki açı yüz gerektiriyor mu?
    let nextAngle = viewModel.session.currentAngle
    let requiresFaceDetection = nextAngle == .frontFace || 
                                nextAngle == .rightProfile || 
                                nextAngle == .leftProfile
    
    if requiresFaceDetection {
      // Yüz tespit edildi mi?
      let faceDetected = viewModel.faceTrackingService.isTracking && 
                        viewModel.faceTrackingService.currentHeadPose != nil
      
      if !faceDetected {
        // Henüz yüz tespit edilmemiş, 0.2 saniye sonra tekrar kontrol et
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          checkAngleTransitionDismiss()
        }
        return
      }
    }
    
    // Her iki koşul da sağlandı - transition'ı kapat
    withAnimation {
      showingAngleTransition = false
      angleTransitionStartTime = nil
    }
  }
}

/// Instructions view for current angle with modern design
struct AngleInstructionView: View {
  let angle: CaptureAngle

  var body: some View {
    HStack(spacing: 14) {
      // Icon with background
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.2))
          .frame(width: 44, height: 44)

        Image(systemName: angle.symbolName)
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.white)
      }

      VStack(alignment: .leading, spacing: 5) {
        // Title
        Text(angle.title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.white)

        // Instructions (compact)
        Text(angle.instructions)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(2)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(
      Capsule()
        .fill(Color.black.opacity(0.4))
        .background(
          Capsule()
            .fill(.ultraThinMaterial)
        )
    )
    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    .padding(.horizontal, 20)
    .fixedSize(horizontal: false, vertical: true)
  }
}

/// Minimal debug overlay - compact info display
struct DebugOverlayView: View {
  let trackingState: String
  let isTracking: Bool
  let headPose: HeadPose?

  var body: some View {
    VStack(alignment: .trailing, spacing: 3) {
      // Compact tracking status
      HStack(spacing: 4) {
        Circle()
          .fill(isTracking ? Color.green : Color.red)
          .frame(width: 6, height: 6)
        Text(trackingState)
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundColor(.white.opacity(0.8))
      }

      // Minimal pose values
      if let pose = headPose {
        HStack(spacing: 6) {
          Text("Y")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.cyan.opacity(0.7))
          Text(String(format: "%+.0f°", pose.yawDegrees))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.cyan)
        }
        
        HStack(spacing: 6) {
          Text("P")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.orange.opacity(0.7))
          Text(String(format: "%+.0f°", pose.pitchDegrees))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.orange)
        }
      } else {
        Text("No Face")
          .font(.system(size: 8, weight: .medium))
          .foregroundColor(.red.opacity(0.8))
      }
    }
    .padding(6)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.black.opacity(0.6))
    )
  }
}

/// Single pose value row for debug overlay
struct PoseValueRow: View {
  let label: String
  let value: Double
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Text(label)
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundColor(.white.opacity(0.6))
        .frame(width: 35, alignment: .trailing)

      Text(String(format: "%+6.1f°", value))
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundColor(color)
        .frame(width: 60, alignment: .trailing)
    }
  }
}

/// Flash control button with cycle through modes
struct FlashControlButton: View {
  @ObservedObject var cameraService: CameraService

  var body: some View {
    Button(action: {
      // Toggle between off and auto: off <-> auto
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        switch cameraService.flashMode {
        case .off:
          cameraService.flashMode = .auto
        case .auto:
          cameraService.flashMode = .off
        }
      }
    }) {
      VStack(spacing: 4) {
        Image(systemName: cameraService.flashMode.icon)
          .font(.system(size: 24, weight: .semibold))
          .foregroundColor(flashColor)

        Text(cameraService.flashMode.rawValue)
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.white.opacity(0.9))
      }
      .frame(width: 60, height: 60)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.black.opacity(0.4))
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(.ultraThinMaterial)
          )
      )
      .shadow(color: .black.opacity(0.3), radius: 8)
    }
  }

  private var flashColor: Color {
    switch cameraService.flashMode {
    case .off:
      return .white.opacity(0.6)
    case .auto:
      return .white
    }
  }
}
