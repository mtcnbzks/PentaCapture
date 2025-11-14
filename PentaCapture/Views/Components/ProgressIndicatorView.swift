//
//  ProgressIndicatorView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Progress indicator showing which angle is being captured
struct ProgressIndicatorView: View {
  let currentAngle: CaptureAngle
  let capturedAngles: Set<CaptureAngle>

  var body: some View {
    HStack(spacing: 10) {
      ForEach(CaptureAngle.allCases) { angle in
        AngleIndicator(
          angle: angle,
          isCurrent: angle == currentAngle,
          isCaptured: capturedAngles.contains(angle)
        )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      Capsule()
        .fill(Color.black.opacity(0.4))
        .background(
          Capsule()
            .fill(.ultraThinMaterial)
        )
    )
  }
}

/// Individual angle indicator
struct AngleIndicator: View {
  let angle: CaptureAngle
  let isCurrent: Bool
  let isCaptured: Bool

  var body: some View {
    ZStack {
      // Background with glow effect for current
      if isCurrent {
        Circle()
          .fill(
            RadialGradient(
              colors: [Color.blue.opacity(0.4), Color.clear],
              center: .center,
              startRadius: 16,
              endRadius: 24
            )
          )
          .frame(width: 48, height: 48)
      }
      
      Circle()
        .fill(backgroundColor)
        .frame(width: 32, height: 32)
        .shadow(color: shadowColor, radius: isCurrent ? 6 : 3)

      if isCaptured {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.white)
      } else {
        Text("\(angle.rawValue + 1)")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(textColor)
      }
    }
    .overlay(
      Circle()
        .stroke(isCurrent ? Color.white : Color.clear, lineWidth: 2.5)
        .frame(width: 36, height: 36)
    )
    .scaleEffect(isCurrent ? 1.1 : 1.0)
    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isCurrent)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCaptured)
  }

  private var backgroundColor: Color {
    if isCaptured {
      return .green
    } else if isCurrent {
      return .blue
    } else {
      return .gray.opacity(0.3)
    }
  }

  private var textColor: Color {
    isCurrent ? .white : .white.opacity(0.6)
  }
  
  private var shadowColor: Color {
    if isCaptured {
      return .green.opacity(0.6)
    } else if isCurrent {
      return .blue.opacity(0.6)
    } else {
      return .clear
    }
  }
}
