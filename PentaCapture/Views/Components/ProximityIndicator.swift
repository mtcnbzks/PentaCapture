//
//  ProximityIndicator.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

/// Large, prominent proximity indicator showing how close user is to correct position
/// This addresses the brief's key requirement: "Doğru pozisyona ne kadar yakın olduğunu gösteren anlık görsel geribildirim"
struct ProximityIndicator: View {
  let progress: Double  // 0.0 - 1.0
  @State private var animateProgress: Double = 0.0

  var body: some View {
    // Minimal circular progress ring
    ZStack {
      // Background circle
      Circle()
        .stroke(Color.white.opacity(0.15), lineWidth: 12)
        .frame(width: 100, height: 100)

      // Progress arc
      Circle()
        .trim(from: 0, to: animateProgress)
        .stroke(
          progressColor,
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .frame(width: 100, height: 100)
        .rotationEffect(.degrees(-90))
        .shadow(color: progressColor.opacity(0.6), radius: 8)

      // Center percentage (compact)
      Text("\(Int(progress * 100))%")
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .contentTransition(.numericText())
    }
    .onChange(of: progress) { newValue in
      withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        animateProgress = newValue
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        animateProgress = progress
      }
    }
  }

  private var progressColor: Color {
    switch progress {
    case 0..<0.3:
      return .red
    case 0.3..<0.6:
      return .orange
    case 0.6..<0.85:
      return .yellow
    default:
      return .green
    }
  }

  private var statusText: String {
    switch progress {
    case 0..<0.3:
      return "Pozisyon Ayarla"
    case 0.3..<0.6:
      return "Yaklaşıyorsun..."
    case 0.6..<0.85:
      return "Neredeyse Hazır!"
    case 0.85..<0.95:
      return "Çok İyi - Sabit Tut"
    default:
      return "Mükemmel! ✓"
    }
  }
}
