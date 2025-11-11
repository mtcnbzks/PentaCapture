//
//  AngleTransitionView.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

/// Professional transition animation between capture angles
struct AngleTransitionView: View {
    let completedAngle: CaptureAngle
    let nextAngle: CaptureAngle
    let capturedCount: Int
    let totalCount: Int
    
    @State private var showCompleted = false
    @State private var showNext = false
    @State private var showProgress = false
    @State private var progressValue: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Dark background with blur
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Completed angle section
                VStack(spacing: 20) {
                    // Success checkmark
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .scaleEffect(showCompleted ? 1.0 : 0.5)
                            .rotationEffect(.degrees(showCompleted ? 0 : -180))
                    }
                    
                    Text(completedAngle.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(showCompleted ? 1 : 0)
                    
                    Text("Tamamlandı!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .opacity(showCompleted ? 1 : 0)
                }
                .padding(.vertical, 30)
                .opacity(showCompleted ? 1 : 0)
                
                // Progress bar
                if showProgress {
                    VStack(spacing: 12) {
                        // Overall progress
                        HStack(spacing: 8) {
                            ForEach(0..<totalCount, id: \.self) { index in
                                Capsule()
                                    .fill(index < capturedCount ? Color.green : Color.white.opacity(0.3))
                                    .frame(width: 50, height: 8)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                        
                        Text("\(capturedCount) / \(totalCount) Fotoğraf")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.vertical, 20)
                }
                
                // Divider with arrow
                if showNext {
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .frame(width: 200)
                        
                        Image(systemName: "arrow.down")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                        
                        Text("Sıradaki Açı")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Next angle section
                VStack(spacing: 20) {
                    // Next angle icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: nextAngle.symbolName)
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .scaleEffect(showNext ? 1.0 : 0.5)
                    }
                    
                    Text(nextAngle.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Instructions
                    Text(nextAngle.instructions)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(3)
                }
                .padding(.vertical, 30)
                .opacity(showNext ? 1 : 0)
                
                Spacer()
                
                // Ready indicator
                if showNext {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.blue)
                        
                        Text("Hazırlanıyor...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            // Staggered animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCompleted = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showProgress = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showNext = true
                }
            }
        }
    }
}

/// Quick transition without animation (for rapid captures)
struct QuickAngleTransition: View {
    let nextAngle: CaptureAngle
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // "Sıradaki" başlığı
                Text("SIRADAKI")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue.opacity(0.8))
                    .tracking(3)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: nextAngle.symbolName)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)
                }
                
                // Angle title
                Text(nextAngle.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Instructions
                Text(nextAngle.instructions)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                
                // Ready indicator
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                    Text("Hazır olduğunuzda devam edin")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
            .padding(40)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

/// Minimalist angle indicator (overlay on camera)
struct MinimalAngleIndicator: View {
    let angle: CaptureAngle
    let isChanging: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            Image(systemName: angle.symbolName)
                .font(.title2)
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: isChanging)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(angle.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(angle.rawValue + 1)/5")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(radius: 10)
    }
}

// MARK: - Preview
#if DEBUG
struct AngleTransitionView_Previews: PreviewProvider {
    static var previews: some View {
        AngleTransitionView(
            completedAngle: .frontFace,
            nextAngle: .rightProfile,
            capturedCount: 1,
            totalCount: 5
        )
    }
}
#endif

