//
//  AngleTransitionView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

struct QuickAngleTransition: View {
  let nextAngle: CaptureAngle

  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0
  @State private var glowScale: CGFloat = 0.8

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        Text("SIRADAKI")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .blue.opacity(0.7)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .tracking(3)

        ZStack {
          Circle()
            .fill(
              RadialGradient(
                colors: [Color.blue.opacity(0.3), .clear],
                center: .center,
                startRadius: 60,
                endRadius: 90
              )
            )
            .frame(width: 180, height: 180)
            .scaleEffect(glowScale)

          Circle()
            .fill(Color.white.opacity(0.1))
            .background(Circle().fill(.ultraThinMaterial))
            .frame(width: 120, height: 120)
            .shadow(color: .blue.opacity(0.5), radius: 20)

          Image(systemName: nextAngle.symbolName)
            .font(.system(size: 50, weight: .medium))
            .foregroundStyle(
              LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .scaleEffect(scale)
        }

        Text(nextAngle.title)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(
            LinearGradient(
              colors: [.white, .white.opacity(0.9)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: .black.opacity(0.3), radius: 4)

        Text(nextAngle.instructions)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white.opacity(0.85))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
          .lineSpacing(5)

        HStack(spacing: 10) {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(
              LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .leading,
                endPoint: .trailing
              ))
          Text("Hazır olduğunuzda devam edin")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.1))
            .background(Capsule().fill(.ultraThinMaterial))
        )
        .padding(.top, 12)
      }
      .padding(40)
      .opacity(opacity)
    }
    .onAppear {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
        scale = 1.0
        opacity = 1.0
        glowScale = 1.2
      }
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
        glowScale = 1.0
      }
    }
  }
}
