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
    // Minimal countdown - just number
    Text("\(countdown)")
      .font(.system(size: 80, weight: .bold, design: .rounded))
      .foregroundColor(countdownColor)
      .scaleEffect(scale)
      .shadow(color: countdownColor.opacity(0.8), radius: 15)
      .padding(30)
      .background(
        Circle()
          .fill(Color.black.opacity(0.5))
      )
      .onChange(of: countdown) { _ in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
          scale = 1.2
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
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
