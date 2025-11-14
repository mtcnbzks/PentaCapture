//
//  CountdownView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Countdown with preparation message
struct CountdownWithMessageView: View {
  let countdown: Int
  @State private var scale: CGFloat = 1.0

  var body: some View {
    // Modern countdown with glassmorphism and glow
    ZStack {
      // Outer glow ring
      Circle()
        .fill(
          RadialGradient(
            colors: [countdownColor.opacity(0.4), Color.clear],
            center: .center,
            startRadius: 60,
            endRadius: 100
          )
        )
        .frame(width: 200, height: 200)
        .scaleEffect(scale * 1.2)
      
      // Main circle with glassmorphism
      Circle()
        .fill(Color.black.opacity(0.3))
        .background(
          Circle()
            .fill(.ultraThinMaterial)
        )
        .frame(width: 120, height: 120)
        .overlay(
          Circle()
            .stroke(countdownColor, lineWidth: 4)
            .frame(width: 120, height: 120)
        )
        .shadow(color: countdownColor.opacity(0.6), radius: 20)
      
      // Number with gradient
      Text("\(countdown)")
        .font(.system(size: 70, weight: .bold, design: .rounded))
        .foregroundStyle(
          LinearGradient(
            colors: [.white, countdownColor.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .shadow(color: countdownColor.opacity(0.8), radius: 15)
        .scaleEffect(scale)
    }
    .onChange(of: countdown) { _ in
      withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
        scale = 1.3
      }
      withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.08)) {
        scale = 1.0
      }
    }
  }

  private var countdownColor: Color {
    switch countdown {
    case 3:
      return .yellow
    case 2:
      return .orange
    case 1:
      return .green
    default:
      return .white
    }
  }
}
