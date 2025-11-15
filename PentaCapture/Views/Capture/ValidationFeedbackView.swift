//
//  ValidationFeedbackView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Real-time visual feedback for validation status
struct ValidationFeedbackView: View {
  let validation: PoseValidation?

  var body: some View {
    VStack(spacing: 0) {
      if let validation = validation {
        // Only show detailed metrics - minimal design
        ValidationMetricsView(validation: validation)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

/// Status indicator with color and icon
struct StatusIndicatorView: View {
  let status: ValidationStatus

  var body: some View {
    HStack(spacing: 12) {
      // Animated status icon
      ZStack {
        Circle()
          .fill(statusColor)
          .frame(width: 44, height: 44)

        Image(systemName: statusIcon)
          .font(.system(size: 22))
          .foregroundColor(.white)
      }
      .shadow(color: statusColor.opacity(0.6), radius: 8)

      // Status text
      Text(statusText)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundColor(.white)
    }
    .animation(.easeInOut(duration: 0.3), value: status)
  }

  private var statusColor: Color {
    switch status {
    case .invalid:
      return .red
    case .adjusting:
      return .orange
    case .valid:
      return .yellow
    case .locked:
      return .green
    }
  }

  private var statusIcon: String {
    switch status {
    case .invalid:
      return "xmark.circle.fill"
    case .adjusting:
      return "arrow.triangle.2.circlepath"
    case .valid:
      return "checkmark.circle"
    case .locked:
      return "lock.circle.fill"
    }
  }

  private var statusText: String {
    switch status {
    case .invalid:
      return "Pozisyon Gerekli"
    case .adjusting:
      return "Ayarlanıyor..."
    case .valid:
      return "İyi - Sabit Tutun"
    case .locked:
      return "Kilitlendi!"
    }
  }
}

/// Minimal validation metrics
struct ValidationMetricsView: View {
  let validation: PoseValidation

  var body: some View {
    // Son 2 adımda (vertex, donorArea) yüz açısı göstermiyoruz - yüz yok zaten
    // Sadece ilk 3 adımda (frontFace, rightProfile, leftProfile) göster
    // Yaw metric (Face direction) - for frontFace, leftProfile, rightProfile
    if let currentYaw = validation.orientationValidation.currentYaw,
      let targetYaw = validation.orientationValidation.targetYaw
    {
      let yawError = abs(currentYaw - targetYaw)
      let yawStatus =
        yawError <= 25 ? ValidationStatus.valid : ValidationStatus.adjusting(progress: 0.5)

      HStack(spacing: 12) {
        // Face tracking icon - minimal
        Image(systemName: "face.smiling")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.white.opacity(0.5))

        // Direction arrow (if needed) - modern icon
        if currentYaw < -5 {
          Image(systemName: "arrow.left.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.white.opacity(0.8))
        } else if currentYaw > 5 {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.white.opacity(0.8))
        }

        // Large current angle value with gradient
        Text(String(format: "%.0f°", abs(currentYaw)))
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [.white, .white.opacity(0.9)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .monospacedDigit()
          .shadow(color: .black.opacity(0.4), radius: 4)

        // Minimal target reference
        Text("→ \(String(format: "%.0f°", targetYaw))")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white.opacity(0.5))
          .monospacedDigit()

        // Modern status indicator with glow
        Circle()
          .fill(yawStatusColor(yawStatus))
          .frame(width: 12, height: 12)
          .shadow(color: yawStatusColor(yawStatus).opacity(0.8), radius: 6)
          .overlay(
            Circle()
              .stroke(yawStatusColor(yawStatus).opacity(0.5), lineWidth: 2)
              .frame(width: 20, height: 20)
          )
      }
      .padding(.horizontal, 20)
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
      .fixedSize(horizontal: true, vertical: false)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    // Son 2 adımda (vertex, donorArea) hiçbir şey gösterme - yüz yok zaten
    // Kullanıcı sadece proximity indicator'a bakacak
  }

  private func yawStatusColor(_ status: ValidationStatus) -> Color {
    switch status {
    case .invalid:
      return .red
    case .adjusting:
      return .orange
    case .valid, .locked:
      return .green
    }
  }

  private func statusColor(_ status: ValidationStatus) -> Color {
    switch status {
    case .invalid:
      return .red
    case .adjusting:
      return .orange
    case .valid, .locked:
      return .green
    }
  }
}

/// Single metric row
struct MetricRow: View {
  let icon: String
  let label: String
  let status: ValidationStatus
  let detail: String

  var body: some View {
    HStack {
      Image(systemName: icon)
        .frame(width: 20)

      Text(label)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(detail)
        .fontWeight(.semibold)

      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
    }
    .foregroundColor(.white.opacity(0.9))
  }

  private var statusColor: Color {
    switch status {
    case .invalid:
      return .red
    case .adjusting:
      return .orange
    case .valid, .locked:
      return .green
    }
  }
}

/// Progress bar showing validation progress
struct ValidationProgressBar: View {
  let progress: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Background
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.white.opacity(0.2))

        // Progress fill
        RoundedRectangle(cornerRadius: 4)
          .fill(progressColor)
          .frame(width: geometry.size.width * progress)
          .animation(.easeInOut(duration: 0.3), value: progress)
      }
    }
    .frame(height: 8)
  }

  private var progressColor: Color {
    if progress < 0.3 {
      return .red
    } else if progress < 0.7 {
      return .orange
    } else if progress < 0.95 {
      return .yellow
    } else {
      return .green
    }
  }
}

/// Compact validation feedback for minimal UI
struct CompactValidationFeedback: View {
  let validation: PoseValidation?

  var body: some View {
    HStack(spacing: 12) {
      if let validation = validation {
        // Status dot
        Circle()
          .fill(statusColor(validation.overallStatus))
          .frame(width: 12, height: 12)

        // Message
        Text(validation.primaryFeedback)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.white)

        Spacer()

        // Progress percentage
        Text("\(Int(validation.progress * 100))%")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundColor(.white)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(
      Capsule()
        .fill(Color.black.opacity(0.7))
    )
  }

  private func statusColor(_ status: ValidationStatus) -> Color {
    switch status {
    case .invalid:
      return .red
    case .adjusting:
      return .orange
    case .valid:
      return .yellow
    case .locked:
      return .green
    }
  }
}

/// Animated validation indicator
struct AnimatedValidationIndicator: View {
  let validation: PoseValidation?
  @State private var animationAmount: CGFloat = 1.0

  var body: some View {
    ZStack {
      if let validation = validation, validation.overallStatus == .locked {
        // Success animation
        Circle()
          .stroke(Color.green, lineWidth: 3)
          .scaleEffect(animationAmount)
          .opacity(2 - animationAmount)

        Image(systemName: "checkmark")
          .font(.system(size: 40, weight: .bold))
          .foregroundColor(.green)
      }
    }
    .frame(width: 80, height: 80)
    .onChange(of: validation?.overallStatus) { newValue in
      if case .locked = newValue {
        withAnimation(.easeOut(duration: 0.6).repeatCount(1, autoreverses: false)) {
          animationAmount = 2.0
        }
      }
    }
  }
}

// MARK: - Preview
#if DEBUG
  struct ValidationFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
          // Invalid state
          ValidationFeedbackView(
            validation: PoseValidation(
              orientationValidation: OrientationValidation(
                status: .invalid,
                currentPitch: 10,
                targetPitch: 0,
                pitchError: 10,
                currentYaw: nil,
                targetYaw: nil,
                yawError: nil,
                currentRoll: nil,
                targetRoll: nil,
                rollError: nil
              ),
              detectionValidation: DetectionValidation(
                status: .invalid,
                boundingBox: nil,
                size: 0,
                centerOffset: .zero,
                isDetected: false
              ),
              isStable: false,
              stabilityDuration: 0
            )
          )

          // Locked state
          ValidationFeedbackView(
            validation: PoseValidation(
              orientationValidation: OrientationValidation(
                status: .valid,
                currentPitch: 0,
                targetPitch: 0,
                pitchError: 0,
                currentYaw: nil,
                targetYaw: nil,
                yawError: nil,
                currentRoll: nil,
                targetRoll: nil,
                rollError: nil
              ),
              detectionValidation: DetectionValidation(
                status: .valid,
                boundingBox: CGRect(x: 100, y: 100, width: 200, height: 250),
                size: 0.4,
                centerOffset: .zero,
                isDetected: true
              ),
              isStable: true,
              stabilityDuration: 0.6
            )
          )
        }
      }
    }
  }
#endif
