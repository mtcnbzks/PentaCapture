//
//  ValidationFeedbackView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

struct ValidationFeedbackView: View {
  let validation: PoseValidation?

  var body: some View {
    if let validation {
      ValidationMetricsView(validation: validation)
    }
  }
}

struct StatusIndicatorView: View {
  let status: ValidationStatus

  private var statusColor: Color {
    switch status {
    case .invalid: .red
    case .adjusting: .orange
    case .valid: .yellow
    case .locked: .green
    }
  }

  private var statusIcon: String {
    switch status {
    case .invalid: "xmark.circle.fill"
    case .adjusting: "arrow.triangle.2.circlepath"
    case .valid: "checkmark.circle"
    case .locked: "lock.circle.fill"
    }
  }

  private var statusText: String {
    switch status {
    case .invalid: "Pozisyon Gerekli"
    case .adjusting: "Ayarlanıyor..."
    case .valid: "İyi - Sabit Tutun"
    case .locked: "Kilitlendi!"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(statusColor)
          .frame(width: 44, height: 44)
        Image(systemName: statusIcon)
          .font(.system(size: 22))
          .foregroundColor(.white)
      }
      .shadow(color: statusColor.opacity(0.6), radius: 8)

      Text(statusText)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundColor(.white)
    }
    .animation(.easeInOut(duration: 0.3), value: status)
  }
}

struct ValidationMetricsView: View {
  let validation: PoseValidation

  var body: some View {
    Group {
      if let currentYaw = validation.orientationValidation.currentYaw,
         let targetYaw = validation.orientationValidation.targetYaw {
        yawMetricContent(currentYaw: currentYaw, targetYaw: targetYaw)
      } else {
        Color.clear
      }
    }
    .frame(width: 180, height: 50)
  }

  @ViewBuilder
  private func yawMetricContent(currentYaw: Double, targetYaw: Double) -> some View {
    let yawError = abs(currentYaw - targetYaw)
    let yawStatus: ValidationStatus = yawError <= 25 ? .valid : .adjusting(progress: 0.5)

    HStack(spacing: 8) {
      Image(systemName: "face.smiling")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white.opacity(0.5))

      if currentYaw < -5 {
        Image(systemName: "arrow.left.circle.fill")
          .font(.system(size: 18))
          .foregroundColor(.white.opacity(0.8))
      } else if currentYaw > 5 {
        Image(systemName: "arrow.right.circle.fill")
          .font(.system(size: 18))
          .foregroundColor(.white.opacity(0.8))
      }

      Text(String(format: "%.0f°", abs(currentYaw)))
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(LinearGradient(
          colors: [.white, .white.opacity(0.9)],
          startPoint: .top,
          endPoint: .bottom
        ))
        .monospacedDigit()
        .shadow(color: .black.opacity(0.4), radius: 3)

      Text("→ \(String(format: "%.0f°", targetYaw))")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.5))
        .monospacedDigit()

      Circle()
        .fill(statusColor(yawStatus))
        .frame(width: 10, height: 10)
        .shadow(color: statusColor(yawStatus).opacity(0.8), radius: 4)
        .overlay(
          Circle()
            .stroke(statusColor(yawStatus).opacity(0.5), lineWidth: 2)
            .frame(width: 16, height: 16)
        )
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      Capsule()
        .fill(Color.black.opacity(0.4))
        .background(Capsule().fill(.ultraThinMaterial))
    )
    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
  }

  private func statusColor(_ status: ValidationStatus) -> Color {
    switch status {
    case .invalid: .red
    case .adjusting: .orange
    case .valid, .locked: .green
    }
  }
}

struct MetricRow: View {
  let icon: String
  let label: String
  let status: ValidationStatus
  let detail: String

  private var statusColor: Color {
    switch status {
    case .invalid: .red
    case .adjusting: .orange
    case .valid, .locked: .green
    }
  }

  var body: some View {
    HStack {
      Image(systemName: icon).frame(width: 20)
      Text(label).frame(maxWidth: .infinity, alignment: .leading)
      Text(detail).fontWeight(.semibold)
      Circle().fill(statusColor).frame(width: 8, height: 8)
    }
    .foregroundColor(.white.opacity(0.9))
  }
}

struct ValidationProgressBar: View {
  let progress: Double

  private var progressColor: Color {
    switch progress {
    case ..<0.3: .red
    case 0.3..<0.7: .orange
    case 0.7..<0.95: .yellow
    default: .green
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.white.opacity(0.2))
        RoundedRectangle(cornerRadius: 4)
          .fill(progressColor)
          .frame(width: geometry.size.width * progress)
          .animation(.easeInOut(duration: 0.3), value: progress)
      }
    }
    .frame(height: 8)
  }
}

struct CompactValidationFeedback: View {
  let validation: PoseValidation?

  private func statusColor(_ status: ValidationStatus) -> Color {
    switch status {
    case .invalid: .red
    case .adjusting: .orange
    case .valid: .yellow
    case .locked: .green
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      if let validation {
        Circle()
          .fill(statusColor(validation.overallStatus))
          .frame(width: 12, height: 12)
        Text(validation.primaryFeedback)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.white)
        Spacer()
        Text("\(Int(validation.progress * 100))%")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundColor(.white)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Capsule().fill(Color.black.opacity(0.7)))
  }
}

struct AnimatedValidationIndicator: View {
  let validation: PoseValidation?
  @State private var animationAmount: CGFloat = 1.0

  var body: some View {
    ZStack {
      if let validation, validation.overallStatus == .locked {
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
