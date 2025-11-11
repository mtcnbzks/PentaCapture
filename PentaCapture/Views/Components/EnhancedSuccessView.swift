//
//  EnhancedSuccessView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import Foundation
import SwiftUI

/// Compact success view without confetti (for quick transitions)
struct CompactSuccessView: View {
  @State private var scale: CGFloat = 0.5

  var body: some View {
    ZStack {
      // Pulsing background
      Circle()
        .fill(Color.green.opacity(0.3))
        .frame(width: 100, height: 100)
        .scaleEffect(scale)

      // Checkmark
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 80))
        .foregroundColor(.green)
        .scaleEffect(scale)
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
        scale = 1.0
      }
      withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
        scale = 1.1
      }
    }
  }
}
