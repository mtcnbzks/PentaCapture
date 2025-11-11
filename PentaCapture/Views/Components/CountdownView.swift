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
    VStack(spacing: 24) {
      // Message
      Text(countdownMessage)
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.5), radius: 2)

      // Countdown
      Text("\(countdown)")
        .font(.system(size: 100, weight: .bold, design: .rounded))
        .foregroundColor(countdownColor)
        .scaleEffect(scale)
        .shadow(color: countdownColor.opacity(0.5), radius: 20)
    }
    .padding(40)
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color.black.opacity(0.7))
        .blur(radius: 10)
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

  private var countdownMessage: String {
    switch countdown {
    case 3:
      return "Hazırlanın..."
    case 2:
      return "Pozisyonu Koruyun"
    case 1:
      return "Hareket Etmeyin!"
    default:
      return "Çekiliyor!"
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
