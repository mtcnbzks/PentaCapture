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
  @AppStorage("debugMode") private var debugMode = false
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
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
        // Show transition briefly
        withAnimation {
          showingAngleTransition = true
        }

        // Hide after 1.2 seconds - give user time to read next angle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
          withAnimation {
            showingAngleTransition = false
          }
        }
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
      // Close button
      Button(action: {
        dismiss()
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 30))
          .foregroundColor(.white)
          .shadow(radius: 2)
      }

      Spacer()

      // Progress indicator
      ProgressIndicatorView(
        currentAngle: viewModel.session.currentAngle,
        capturedAngles: Set(viewModel.session.capturedPhotos.map { $0.angle })
      )

      Spacer()

      // Instructions toggle
      Button(action: {
        withAnimation {
          showingInstructions.toggle()
        }
      }) {
        Image(systemName: showingInstructions ? "info.circle.fill" : "info.circle")
          .font(.system(size: 30))
          .foregroundColor(.white)
          .shadow(radius: 2)
      }
    }
    .padding()
  }

  private var bottomControls: some View {
    HStack(spacing: 30) {
      // Skip/Previous button
      if viewModel.session.currentAngle.rawValue > 0 {
        Button(action: {
          viewModel.goToPreviousAngle()
        }) {
          Image(systemName: "chevron.left.circle")
            .font(.system(size: 44))
            .foregroundColor(.white)
            .shadow(radius: 2)
        }
      }

      Spacer()

      Spacer()

      // Review button (if photos exist)
      if !viewModel.session.capturedPhotos.isEmpty {
        Button(action: {
          showingReview = true
        }) {
          ZStack {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.white)
              .frame(width: 44, height: 44)

            if let lastPhoto = viewModel.session.capturedPhotos.last,
              let thumbnail = lastPhoto.image
            {
              Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text("\(viewModel.session.capturedCount)")
              .font(.caption2)
              .fontWeight(.bold)
              .foregroundColor(.white)
              .padding(4)
              .background(Color.red)
              .clipShape(Circle())
              .offset(x: 16, y: -16)
          }
          .shadow(radius: 2)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 10)
  }
}

/// Instructions view for current angle
struct AngleInstructionView: View {
  let angle: CaptureAngle

  var body: some View {
    HStack(spacing: 12) {
      // Icon
      Image(systemName: angle.symbolName)
        .font(.system(size: 24))
        .foregroundColor(.white)

      VStack(alignment: .leading, spacing: 4) {
        // Title
        Text(angle.title)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.white)

        // Instructions (compact)
        Text(angle.instructions)
          .font(.caption)
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      Capsule()
        .fill(Color.black.opacity(0.6))
    )
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
