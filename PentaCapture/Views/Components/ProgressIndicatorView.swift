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
        .fill(Color.black.opacity(0.5))
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
      Circle()
        .fill(backgroundColor)
        .frame(width: 32, height: 32)

      if isCaptured {
        Image(systemName: "checkmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
      } else {
        Text("\(angle.rawValue + 1)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(textColor)
      }
    }
    .overlay(
      Circle()
        .stroke(isCurrent ? Color.white : Color.clear, lineWidth: 2)
        .frame(width: 36, height: 36)
    )
    .scaleEffect(isCurrent ? 1.05 : 1.0)
    .animation(.spring(response: 0.3), value: isCurrent)
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
}
