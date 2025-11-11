//
//  EnhancedSuccessView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI
import Foundation

/// Enhanced success animation with confetti and celebration
struct EnhancedSuccessView: View {
    let angleTitle: String
    let capturedCount: Int
    let totalCount: Int
    
    @State private var showCheckmark = false
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -180
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Confetti particles
            if showConfetti {
                ConfettiView()
            }
            
            // Main success card
            VStack(spacing: 24) {
                // Checkmark with ring
                ZStack {
                    // Outer ring - progress of total capture
                    Circle()
                        .trim(from: 0, to: CGFloat(capturedCount) / CGFloat(totalCount))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    
                    // Inner pulsing circle
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 110, height: 110)
                        .scaleEffect(showCheckmark ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showCheckmark)
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                }
                
                // Success message
                VStack(spacing: 8) {
                    Text("Harika! ✓")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(angleTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<totalCount, id: \.self) { index in
                            Circle()
                                .fill(index < capturedCount ? Color.green : Color.white.opacity(0.3))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 4)
                    
                    Text("\(capturedCount)/\(totalCount) Fotoğraf")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    )
            )
            .shadow(color: .green.opacity(0.3), radius: 20)
        }
        .onAppear {
            // Animate checkmark
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showCheckmark = true
                scale = 1.0
                rotation = 0
            }
            
            // Trigger confetti with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

/// Confetti particle system
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiShape(shape: particle.shape)
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .rotationEffect(.degrees(particle.rotation))
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        for i in 0..<60 {
            let angle = Double(i) * (360.0 / 60.0) * .pi / 180.0
            let velocity = CGFloat.random(in: 100...250)
            
            var particle = ConfettiParticle(
                position: CGPoint(x: centerX, y: centerY),
                velocity: CGPoint(
                    x: CGFloat(Foundation.cos(angle)) * velocity,
                    y: CGFloat(Foundation.sin(angle)) * velocity
                ),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                shape: Int.random(in: 0...2)
            )
            
            particles.append(particle)
            
            // Animate particle
            withAnimation(.easeOut(duration: 2.0)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].position.x += particle.velocity.x
                    particles[index].position.y += particle.velocity.y + 400 // Gravity
                    particles[index].opacity = 0
                    particles[index].rotation = Double.random(in: 0...720)
                }
            }
        }
    }
}

/// Individual confetti particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var shape: Int // 0: circle, 1: square, 2: triangle
    var opacity: Double = 1.0
    var rotation: Double = 0
}

/// Shape for confetti particles
struct ConfettiShape: Shape {
    let shape: Int
    
    func path(in rect: CGRect) -> Path {
        switch shape {
        case 0:
            return Circle().path(in: rect)
        case 1:
            return Rectangle().path(in: rect)
        default:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

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

// MARK: - Preview
#if DEBUG
struct EnhancedSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            EnhancedSuccessView(
                angleTitle: "Tam Yüz Karşıdan",
                capturedCount: 3,
                totalCount: 5
            )
        }
    }
}
#endif

