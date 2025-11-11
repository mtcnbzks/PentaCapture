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
    let progress: Double // 0.0 - 1.0
    @State private var animateProgress: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Large circular progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 20)
                    .frame(width: 160, height: 160)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: animateProgress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: progressColor.opacity(0.8), radius: 10)
                
                // Pulsing inner circle when near perfect
                if progress > 0.85 {
                    Circle()
                        .fill(progressColor.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                }
                
                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("%")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Distance bars - horizontal progress indicator
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < Int(progress * 10) ? progressColor : Color.white.opacity(0.3))
                        .frame(width: 28, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.02), value: progress)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(progressColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(progressColor.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(progressColor, lineWidth: 2)
                        )
                )
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateProgress = newValue
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateProgress = progress
            }
            
            // Pulse animation when near perfect
            if progress > 0.85 {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
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

/// Compact version for when full validation feedback is shown
struct CompactProximityIndicator: View {
    let progress: Double
    @State private var animateProgress: Double = 0.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Small circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: animateProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Mini bars
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index < Int(progress * 5) ? progressColor : Color.white.opacity(0.3))
                        .frame(width: 20, height: 6)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animateProgress = newValue
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animateProgress = progress
            }
        }
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.3: return .red
        case 0.3..<0.6: return .orange
        case 0.6..<0.85: return .yellow
        default: return .green
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ProximityIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                ProximityIndicator(progress: 0.25)
                ProximityIndicator(progress: 0.65)
                ProximityIndicator(progress: 0.92)
                
                CompactProximityIndicator(progress: 0.75)
            }
        }
    }
}
#endif

