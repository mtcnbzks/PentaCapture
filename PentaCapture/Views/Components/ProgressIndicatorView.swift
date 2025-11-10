//
//  ProgressIndicatorView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Progress indicator showing which angle is being captured
struct ProgressIndicatorView: View {
    let currentAngle: CaptureAngle
    let capturedAngles: Set<CaptureAngle>
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(CaptureAngle.allCases) { angle in
                AngleIndicator(
                    angle: angle,
                    isCurrent: angle == currentAngle,
                    isCaptured: capturedAngles.contains(angle)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }
}

/// Individual angle indicator
struct AngleIndicator: View {
    let angle: CaptureAngle
    let isCurrent: Bool
    let isCaptured: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)
            
            if isCaptured {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(angle.rawValue + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent ? Color.white : Color.clear, lineWidth: 2)
                .frame(width: 44, height: 44)
        )
        .scaleEffect(isCurrent ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isCurrent)
    }
    
    private var backgroundColor: Color {
        if isCaptured {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        isCurrent ? .white : .white.opacity(0.6)
    }
}

// MARK: - Preview
#if DEBUG
struct ProgressIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                ProgressIndicatorView(
                    currentAngle: .frontFace,
                    capturedAngles: []
                )
                
                ProgressIndicatorView(
                    currentAngle: .rightProfile,
                    capturedAngles: [.frontFace]
                )
                
                ProgressIndicatorView(
                    currentAngle: .donorArea,
                    capturedAngles: [.frontFace, .rightProfile, .leftProfile, .vertex]
                )
            }
        }
    }
}
#endif

