//
//  AngleTransitionView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

/// Quick transition without animation (for rapid captures)
struct QuickAngleTransition: View {
  let nextAngle: CaptureAngle

  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0

  var body: some View {
    ZStack {
      Color.black.opacity(0.85)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        // "Sıradaki" başlığı
        Text("SIRADAKI")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundColor(.blue.opacity(0.8))
          .tracking(3)

        // Icon
        ZStack {
          Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 120, height: 120)

          Image(systemName: nextAngle.symbolName)
            .font(.system(size: 60))
            .foregroundColor(.blue)
            .scaleEffect(scale)
        }

        // Angle title
        Text(nextAngle.title)
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(.white)

        // Instructions
        Text(nextAngle.instructions)
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.9))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
          .lineSpacing(4)

        // Ready indicator
        HStack(spacing: 8) {
          Image(systemName: "arrow.right.circle.fill")
            .foregroundColor(.blue)
          Text("Hazır olduğunuzda devam edin")
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 8)
      }
      .padding(40)
      .opacity(opacity)
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        scale = 1.0
        opacity = 1.0
      }
    }
  }
}
