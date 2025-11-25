//
//  ProximityIndicator.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

struct ProximityIndicator: View {
  let progress: Double
  @State private var animateProgress: Double = 0.0

  private var progressColor: Color {
    switch progress {
    case 0..<0.3: .red
    case 0.3..<0.6: .orange
    case 0.6..<0.85: .yellow
    default: .green
    }
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [progressColor.opacity(0.3), .clear],
            center: .center,
            startRadius: 40,
            endRadius: 60
          )
        )
        .frame(width: 120, height: 120)

      Circle()
        .stroke(Color.white.opacity(0.2), lineWidth: 12)
        .frame(width: 90, height: 90)
        .background(
          Circle()
            .fill(Color.black.opacity(0.3))
            .background(Circle().fill(.ultraThinMaterial))
            .frame(width: 90, height: 90)
        )

      Circle()
        .trim(from: 0, to: animateProgress)
        .stroke(
          LinearGradient(
            colors: [progressColor, progressColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .frame(width: 90, height: 90)
        .rotationEffect(.degrees(-90))
        .shadow(color: progressColor.opacity(0.8), radius: 10)

      Text("\(Int(progress * 100))%")
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .contentTransition(.numericText())
        .shadow(color: .black.opacity(0.3), radius: 2)
    }
    .onChange(of: progress) { newValue in
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        animateProgress = newValue
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        animateProgress = progress
      }
    }
  }
}
