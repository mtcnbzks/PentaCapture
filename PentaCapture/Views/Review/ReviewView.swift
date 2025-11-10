//
//  ReviewView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// View for reviewing all captured photos
struct ReviewView: View {
    let session: CaptureSession
    let storageService: StorageService
    let onRetake: (CaptureAngle) -> Void
    let onComplete: () -> Void
    let onSaveToGallery: () -> Void
    
    @State private var selectedPhoto: CapturedPhoto?
    @State private var showingSaveConfirmation = false
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Grid of photos
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(CaptureAngle.allCases) { angle in
                            if let photo = session.photo(for: angle) {
                                PhotoThumbnail(photo: photo, angle: angle) {
                                    selectedPhoto = photo
                                } onRetake: {
                                    onRetake(angle)
                                }
                            } else {
                                EmptyPhotoSlot(angle: angle) {
                                    onRetake(angle)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Action buttons
                actionButtons
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo) {
                selectedPhoto = nil
            }
        }
        .alert("Fotoğraflar Kaydedildi", isPresented: $showingSaveConfirmation) {
            Button("Tamam") {
                onComplete()
            }
        } message: {
            Text("5 fotoğraf başarıyla galerinize kaydedildi.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Fotoğraflarınızı İnceleyin")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("\(session.capturedCount)/\(session.totalCount) fotoğraf çekildi")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save to gallery button
            Button(action: {
                saveToGallery()
            }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Galeriye Kaydet")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving || session.capturedCount < session.totalCount)
            
            // Complete button
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Tamamla")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
    }
    
    private func saveToGallery() {
        isSaving = true
        
        Task {
            do {
                _ = try await storageService.saveSessionToGallery(session)
                await MainActor.run {
                    isSaving = false
                    showingSaveConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Show error
                }
            }
        }
    }
}

/// Thumbnail view for a captured photo
struct PhotoThumbnail: View {
    let photo: CapturedPhoto
    let angle: CaptureAngle
    let onTap: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        onTap()
                    }
            }
            
            // Retake button
            Button(action: onRetake) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(8)
            
            // Label
            VStack {
                Spacer()
                Text(angle.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(8)
            }
        }
    }
}

/// Empty slot for uncaptured photo
struct EmptyPhotoSlot: View {
    let angle: CaptureAngle
    let onCapture: () -> Void
    
    var body: some View {
        Button(action: onCapture) {
            VStack(spacing: 12) {
                Image(systemName: angle.symbolName)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(angle.title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.white.opacity(0.3))
            )
        }
    }
}

/// Detail view for a single photo
struct PhotoDetailView: View {
    let photo: CapturedPhoto
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Text(photo.angle.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                
                // Photo
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Açı", value: photo.angle.title)
                    InfoRow(label: "Talimat", value: photo.angle.instructions)
                    InfoRow(label: "Zaman", value: formatDate(photo.timestamp))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Info row for detail view
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a static session to prevent re-adding photos on each render
        let session = {
            let s = CaptureSession()
            // Add mock photos only once by directly setting the array
            if let image = UIImage(systemName: "person.circle.fill") {
                let mockPhotos = CaptureAngle.allCases.prefix(3).map { angle in
                    CapturedPhoto(angle: angle, image: image)
                }
                // Directly set photos instead of using addPhoto to prevent duplicates
                s.capturedPhotos = mockPhotos
            }
            return s
        }()
        
        return ReviewView(
            session: session,
            storageService: StorageService(),
            onRetake: { _ in },
            onComplete: {},
            onSaveToGallery: {}
        )
    }
}
#endif

