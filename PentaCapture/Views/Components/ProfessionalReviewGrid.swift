//
//  ProfessionalReviewGrid.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

/// Professional grid layout for reviewing all 5 captured photos
/// Optimized for hair clinic analysis workflow
struct ProfessionalReviewGrid: View {
    let session: CaptureSession
    let onPhotoTap: (CapturedPhoto) -> Void
    let onRetake: (CaptureAngle) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header stats
                ReviewStatsHeader(session: session)
                
                // Timeline layout
                VStack(spacing: 20) {
                    // Face angles section (3 photos)
                    SectionHeader(
                        icon: "person.crop.circle",
                        title: "Yüz Açıları",
                        count: faceAngles.filter { session.hasPhoto(for: $0) }.count,
                        total: faceAngles.count
                    )
                    
                    // Front (full width)
                    if let frontPhoto = session.photo(for: .frontFace) {
                        TimelinePhotoCard(
                            photo: frontPhoto,
                            angle: .frontFace,
                            layout: .featured,
                            onTap: { onPhotoTap(frontPhoto) },
                            onRetake: { onRetake(.frontFace) }
                        )
                    } else {
                        EmptyTimelineCard(angle: .frontFace, onTap: { onRetake(.frontFace) })
                    }
                    
                    // Right and Left (side by side)
                    HStack(spacing: 12) {
                        if let rightPhoto = session.photo(for: .rightProfile) {
                            TimelinePhotoCard(
                                photo: rightPhoto,
                                angle: .rightProfile,
                                layout: .compact,
                                onTap: { onPhotoTap(rightPhoto) },
                                onRetake: { onRetake(.rightProfile) }
                            )
                        } else {
                            EmptyTimelineCard(angle: .rightProfile, onTap: { onRetake(.rightProfile) })
                        }
                        
                        if let leftPhoto = session.photo(for: .leftProfile) {
                            TimelinePhotoCard(
                                photo: leftPhoto,
                                angle: .leftProfile,
                                layout: .compact,
                                onTap: { onPhotoTap(leftPhoto) },
                                onRetake: { onRetake(.leftProfile) }
                            )
                        } else {
                            EmptyTimelineCard(angle: .leftProfile, onTap: { onRetake(.leftProfile) })
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // Scalp angles section (2 photos)
                    SectionHeader(
                        icon: "circle.hexagongrid",
                        title: "Saç Derisi Açıları",
                        count: scalpAngles.filter { session.hasPhoto(for: $0) }.count,
                        total: scalpAngles.count
                    )
                    
                    // Top and Back (larger, side by side)
                    HStack(spacing: 12) {
                        if let topPhoto = session.photo(for: .vertex) {
                            TimelinePhotoCard(
                                photo: topPhoto,
                                angle: .vertex,
                                layout: .large,
                                onTap: { onPhotoTap(topPhoto) },
                                onRetake: { onRetake(.vertex) }
                            )
                        } else {
                            EmptyTimelineCard(angle: .vertex, onTap: { onRetake(.vertex) })
                        }
                        
                        if let backPhoto = session.photo(for: .donorArea) {
                            TimelinePhotoCard(
                                photo: backPhoto,
                                angle: .donorArea,
                                layout: .large,
                                onTap: { onPhotoTap(backPhoto) },
                                onRetake: { onRetake(.donorArea) }
                            )
                        } else {
                            EmptyTimelineCard(angle: .donorArea, onTap: { onRetake(.donorArea) })
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private var faceAngles: [CaptureAngle] {
        [.frontFace, .rightProfile, .leftProfile]
    }
    
    private var scalpAngles: [CaptureAngle] {
        [.vertex, .donorArea]
    }
}

/// Stats header showing completion status
struct ReviewStatsHeader: View {
    let session: CaptureSession
    
    var body: some View {
        VStack(spacing: 16) {
            // Completion ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(completionColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(session.capturedCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("/\(session.totalCount)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Status text
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(statusSubtext)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
    }
    
    private var completionColor: Color {
        session.isComplete ? .green : .blue
    }
    
    private var statusText: String {
        session.isComplete ? "Tamamlandı! ✓" : "Çekim Devam Ediyor"
    }
    
    private var statusSubtext: String {
        session.isComplete ? "Tüm fotoğraflar başarıyla çekildi" : "\(session.totalCount - session.capturedCount) fotoğraf kaldı"
    }
}

/// Section header for photo groups
struct SectionHeader: View {
    let icon: String
    let title: String
    let count: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(count)/\(total)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(count == total ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
        }
    }
}

/// Timeline photo card with different layout options
struct TimelinePhotoCard: View {
    let photo: CapturedPhoto
    let angle: CaptureAngle
    let layout: CardLayout
    let onTap: () -> Void
    let onRetake: () -> Void
    
    enum CardLayout {
        case featured   // Full width, larger
        case large      // Half width, tall
        case compact    // Half width, standard
        
        var height: CGFloat {
            switch self {
            case .featured: return 240
            case .large: return 200
            case .compact: return 160
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: layout.height)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onTapGesture(perform: onTap)
            }
            
            // Overlay gradient for text readability
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear, Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .cornerRadius(16)
            .allowsHitTesting(false)
            
            // Top right controls
            HStack(spacing: 8) {
                // Retake button
                Button(action: onRetake) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Yeniden")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
            }
            .padding(12)
            
            // Bottom label
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(angle.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if layout == .featured {
                            Text(angle.instructions)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Checkmark badge
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
}

/// Empty card for uncaptured photo
struct EmptyTimelineCard: View {
    let angle: CaptureAngle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: angle.symbolName)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.4))
                
                Text(angle.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Çekmek için dokunun")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundColor(.white.opacity(0.3))
            )
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ProfessionalReviewGrid_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ProfessionalReviewGrid(
                session: {
                    let session = CaptureSession()
                    // Add mock photos
                    if let image = UIImage(systemName: "person.fill") {
                        session.addPhoto(CapturedPhoto(angle: .frontFace, image: image))
                        session.addPhoto(CapturedPhoto(angle: .rightProfile, image: image))
                        session.addPhoto(CapturedPhoto(angle: .vertex, image: image))
                    }
                    return session
                }(),
                onPhotoTap: { _ in },
                onRetake: { _ in }
            )
        }
    }
}
#endif

