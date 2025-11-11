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
    VStack(spacing: 16) {
      // Status indicator
      StatusIndicatorView(status: validation?.overallStatus ?? .invalid)

      // Primary feedback message
      if let validation = validation {
        Text(validation.primaryFeedback)
          .font(.headline)
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
          .shadow(color: .black.opacity(0.5), radius: 2)

        // Detailed metrics
        ValidationMetricsView(validation: validation)
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.black.opacity(0.7))
    )
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
    VStack(spacing: 6) {
      // Yaw metric (Face direction) - Most important for user
      if let currentYaw = validation.orientationValidation.currentYaw,
        let targetYaw = validation.orientationValidation.targetYaw
      {
        let yawError = abs(currentYaw - targetYaw)
        let yawStatus =
          yawError <= 25 ? ValidationStatus.valid : ValidationStatus.adjusting(progress: 0.5)

        HStack(spacing: 6) {
          // Direction arrow and value
          HStack(spacing: 3) {
            if currentYaw < -5 {
              Text("←")
                .font(.system(size: 14, weight: .bold))
            } else if currentYaw > 5 {
              Text("→")
                .font(.system(size: 14, weight: .bold))
            }
            Text(String(format: "%.0f°", abs(currentYaw)))
              .font(.system(size: 16, weight: .bold))
              .monospacedDigit()
          }
          .foregroundColor(.white)

          Text("→")
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.4))

          Text(String(format: "%.0f°", targetYaw))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .monospacedDigit()

          Spacer()

          Circle()
            .fill(yawStatusColor(yawStatus))
            .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.black.opacity(0.5))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(yawStatusColor(yawStatus), lineWidth: 1)
            )
        )
      }

      // Compact status row - other metrics
      HStack(spacing: 8) {
        // Stability indicator
        HStack(spacing: 3) {
          Image(systemName: "target")
            .font(.system(size: 9))
          Text(String(format: "%.1fs", validation.stabilityDuration))
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
        }

        Spacer()

        // Face detection indicator
        if validation.detectionValidation.isDetected {
          HStack(spacing: 3) {
            Image(systemName: "face.smiling")
              .font(.system(size: 9))
            Circle()
              .fill(statusColor(validation.detectionValidation.status))
              .frame(width: 6, height: 6)
          }
        }
      }
      .foregroundColor(.white.opacity(0.7))
      .font(.caption2)
      .padding(.horizontal, 4)
    }
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
                yawError: nil
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
                yawError: nil
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
