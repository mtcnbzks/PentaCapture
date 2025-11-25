//
//  PoseGuideOverlay.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

struct CenterCrosshairView: View {
  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color.white.opacity(0.5))
        .frame(width: 1, height: 40)
      Rectangle()
        .fill(Color.white.opacity(0.5))
        .frame(width: 40, height: 1)
      Circle()
        .fill(Color.white.opacity(0.8))
        .frame(width: 6, height: 6)
    }
  }
}
