//
//  PoseGuideOverlay.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Center crosshair for alignment guidance
struct CenterCrosshairView: View {
  var body: some View {
    ZStack {
      // Vertical line
      Rectangle()
        .fill(Color.white.opacity(0.5))
        .frame(width: 1, height: 40)

      // Horizontal line
      Rectangle()
        .fill(Color.white.opacity(0.5))
        .frame(width: 40, height: 1)

      // Center dot
      Circle()
        .fill(Color.white.opacity(0.8))
        .frame(width: 6, height: 6)
    }
  }
}
