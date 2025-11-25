//
//  EnhancedSuccessView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

struct CompactSuccessView: View {
  @State private var scale: CGFloat = 0.5
  @State private var glowScale: CGFloat = 0.8

  var body: some View {
    ZStack {
      Circle()
        .fill(RadialGradient(
          colors: [Color.green.opacity(0.4), .clear],
          center: .center,
          startRadius: 30,
          endRadius: 60
        ))
        .frame(width: 120, height: 120)
        .scaleEffect(glowScale)

      Circle()
        .fill(Color.black.opacity(0.3))
        .background(Circle().fill(.ultraThinMaterial))
        .frame(width: 80, height: 80)
        .shadow(color: .green.opacity(0.6), radius: 15)

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 60, weight: .bold))
        .foregroundStyle(LinearGradient(
          colors: [.green, .green.opacity(0.8)],
          startPoint: .top,
          endPoint: .bottom
        ))
        .scaleEffect(scale)
        .shadow(color: .green.opacity(0.8), radius: 12)
    }
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
        scale = 1.1
        glowScale = 1.3
      }
      withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
        scale = 1.0
        glowScale = 1.0
      }
    }
  }
}
