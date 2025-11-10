//
//  CountdownView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Animated countdown view shown before capture
struct CountdownView: View {
    let countdown: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Countdown number
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onChange(of: countdown) { _ in
            animateCountdown()
        }
        .onAppear {
            animateCountdown()
        }
    }
    
    private func animateCountdown() {
        // Reset
        scale = 0.5
        opacity = 0.0
        
        // Animate in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.2
            opacity = 1.0
        }
        
        // Animate out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.5
                opacity = 0.0
            }
        }
    }
}

/// Circular countdown timer with progress
struct CircularCountdownView: View {
    let countdown: Int
    let totalTime: Int = 3
    @State private var progress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                .frame(width: 150, height: 150)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: progress)
            
            // Countdown number
            VStack(spacing: 8) {
                Text("\(countdown)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("saniye")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onChange(of: countdown) { newValue in
            progress = Double(totalTime - newValue + 1) / Double(totalTime)
        }
        .onAppear {
            progress = Double(totalTime - countdown + 1) / Double(totalTime)
        }
    }
}

/// Pulsing countdown indicator
struct PulsingCountdownView: View {
    let countdown: Int
    @State private var pulseAmount: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer pulse
            Circle()
                .fill(countdownColor.opacity(0.3))
                .frame(width: 200, height: 200)
                .scaleEffect(pulseAmount)
                .opacity(2 - pulseAmount)
            
            // Inner circle
            Circle()
                .fill(countdownColor)
                .frame(width: 140, height: 140)
            
            // Number
            Text("\(countdown)")
                .font(.system(size: 70, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .onChange(of: countdown) { _ in
            animatePulse()
        }
        .onAppear {
            animatePulse()
        }
    }
    
    private func animatePulse() {
        pulseAmount = 1.0
        withAnimation(.easeOut(duration: 0.8)) {
            pulseAmount = 2.0
        }
    }
    
    private var countdownColor: Color {
        switch countdown {
        case 3:
            return .red
        case 2:
            return .orange
        case 1:
            return .green
        default:
            return .blue
        }
    }
}

/// Minimal countdown view
struct MinimalCountdownView: View {
    let countdown: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { number in
                Circle()
                    .fill(number <= countdown ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }
}

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

/// Success animation after capture
struct CaptureSuccessView: View {
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .opacity(opacity)
                
                Text("Başarılı!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CountdownView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            VStack(spacing: 60) {
                CountdownView(countdown: 3)
                
                CircularCountdownView(countdown: 2)
                
                PulsingCountdownView(countdown: 1)
            }
        }
    }
}
#endif

