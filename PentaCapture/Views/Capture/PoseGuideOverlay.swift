//
//  PoseGuideOverlay.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Visual overlay showing guidance for proper pose positioning
struct PoseGuideOverlay: View {
    let angle: CaptureAngle
    let validation: PoseValidation?
    
    var body: some View {
        ZStack {
            // Guide shape
            guideShape()
                .stroke(guideColor, lineWidth: 3)
                .padding(guidePadding)
                .overlay(
                    guideShape()
                        .fill(guideColor.opacity(0.1))
                        .padding(guidePadding)
                )
            
            // Detection box if available
            if let validation = validation,
               let boundingBox = validation.detectionValidation.boundingBox {
                DetectionBoxView(boundingBox: boundingBox, status: validation.detectionValidation.status)
            }
            
            // Center crosshair
            CenterCrosshairView()
        }
    }
    
    private func guideShape() -> AnyShape {
        switch angle {
        case .frontFace, .rightProfile, .leftProfile:
            return AnyShape(Circle())
        case .vertex, .donorArea:
            return AnyShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var guidePadding: CGFloat {
        switch angle {
        case .frontFace, .rightProfile, .leftProfile:
            return 60
        case .vertex, .donorArea:
            return 40
        }
    }
    
    private var guideColor: Color {
        guard let validation = validation else {
            return .white.opacity(0.5)
        }
        
        switch validation.overallStatus {
        case .invalid:
            return .red
        case .adjusting(let progress):
            return progress > 0.5 ? .yellow : .orange
        case .valid:
            return .yellow
        case .locked:
            return .green
        }
    }
}

/// View showing detected face/head bounding box
struct DetectionBoxView: View {
    let boundingBox: CGRect
    let status: ValidationStatus
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .stroke(boxColor, lineWidth: 2)
                .frame(width: boundingBox.width, height: boundingBox.height)
                .position(
                    x: boundingBox.midX,
                    y: boundingBox.midY
                )
                .overlay(
                    // Corner markers
                    ForEach(0..<4, id: \.self) { corner in
                        CornerMarker()
                            .stroke(boxColor, lineWidth: 3)
                            .frame(width: 20, height: 20)
                            .position(cornerPosition(corner, in: boundingBox))
                    }
                )
        }
    }
    
    private var boxColor: Color {
        switch status {
        case .invalid:
            return .red
        case .adjusting:
            return .yellow
        case .valid, .locked:
            return .green
        }
    }
    
    private func cornerPosition(_ corner: Int, in box: CGRect) -> CGPoint {
        switch corner {
        case 0: // Top-left
            return CGPoint(x: box.minX, y: box.minY)
        case 1: // Top-right
            return CGPoint(x: box.maxX, y: box.minY)
        case 2: // Bottom-left
            return CGPoint(x: box.minX, y: box.maxY)
        case 3: // Bottom-right
            return CGPoint(x: box.maxX, y: box.maxY)
        default:
            return .zero
        }
    }
}

/// Corner marker shape
struct CornerMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Top line
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right line
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        return path
    }
}

/// Center crosshair for alignment
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

/// Animated guide silhouette
struct AnimatedGuideSilhouette: View {
    let angle: CaptureAngle
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Pulsing effect
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .scaleEffect(animationAmount)
                .opacity(2 - animationAmount)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: animationAmount
                )
            
            // Icon for angle type
            Image(systemName: angle.symbolName)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))
        }
        .onAppear {
            animationAmount = 2.0
        }
    }
}

/// Progress arc showing validation progress
struct ValidationProgressArc: View {
    let progress: Double
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                progressColor,
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .padding(20)
            .animation(.easeInOut(duration: 0.3), value: progress)
    }
    
    private var progressColor: Color {
        if progress < 0.3 {
            return .red
        } else if progress < 0.7 {
            return .orange
        } else if progress < 0.95 {
            return .yellow
        } else {
            return .green
        }
    }
}

/// Complete pose guide with all visual elements
struct CompletePoseGuide: View {
    let angle: CaptureAngle
    let validation: PoseValidation?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Main guide
            PoseGuideOverlay(angle: angle, validation: validation)
            
            // Progress arc
            if let validation = validation {
                ValidationProgressArc(progress: validation.progress)
            }
            
            // Animated silhouette when no detection
            if validation?.detectionValidation.isDetected == false {
                AnimatedGuideSilhouette(angle: angle)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct PoseGuideOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Invalid state
                PoseGuideOverlay(
                    angle: .frontFace,
                    validation: PoseValidation(
                        orientationValidation: OrientationValidation(
                            status: .invalid,
                            currentPitch: 10,
                            targetPitch: 0,
                            pitchError: 10,
                            currentYaw: nil,
                            targetYaw: nil,
                            yawError: nil
                        ),
                        detectionValidation: DetectionValidation(
                            status: .invalid,
                            boundingBox: nil,
                            size: 0,
                            centerOffset: .zero,
                            isDetected: false
                        ),
                        isStable: false,
                        stabilityDuration: 0
                    )
                )
                .frame(height: 200)
                
                // Valid state
                PoseGuideOverlay(
                    angle: .frontFace,
                    validation: PoseValidation(
                        orientationValidation: OrientationValidation(
                            status: .valid,
                            currentPitch: 0,
                            targetPitch: 0,
                            pitchError: 0,
                            currentYaw: nil,
                            targetYaw: nil,
                            yawError: nil
                        ),
                        detectionValidation: DetectionValidation(
                            status: .valid,
                            boundingBox: CGRect(x: 100, y: 100, width: 200, height: 250),
                            size: 0.4,
                            centerOffset: .zero,
                            isDetected: true
                        ),
                        isStable: true,
                        stabilityDuration: 0.3
                    )
                )
                .frame(height: 200)
            }
        }
    }
}
#endif

