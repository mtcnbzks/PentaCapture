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
    // Ultra minimal checkmark
    Image(systemName: "checkmark.circle.fill")
      .font(.system(size: 60))
      .foregroundColor(.green)
      .scaleEffect(scale)
      .shadow(color: .green.opacity(0.6), radius: 10)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          scale = 1.0
        }
      }
  }
}
