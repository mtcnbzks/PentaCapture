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
  @State private var showingShareSheet = false
  @State private var showProfessionalGrid = true  // Toggle between layouts
  @State private var showHeatMap = false
  @State private var exportedJSONURL: URL?
  @State private var exportError: String?
  @State private var isExportingJSON = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 0) {
        // Header with layout toggle
        headerView

        // Main content area
        if showProfessionalGrid {
          // Professional Timeline Grid
          ProfessionalReviewGrid(
            session: session,
            onPhotoTap: { photo in
              selectedPhoto = photo
            },
            onRetake: onRetake
          )
        } else {
          // Original Grid Layout
          ScrollView {
            LazyVGrid(
              columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
              ], spacing: 16
            ) {
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
        }

        // Heat Map (expandable)
        if showHeatMap {
          ProgressHeatMap(angleStats: session.getAngleStatsArray())
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
    .sheet(isPresented: $showingShareSheet) {
      if let activityVC = storageService.createShareSheet(for: session) {
        ActivityViewController(activityViewController: activityVC)
      }
    }
    .alert("Fotoğraflar Kaydedildi", isPresented: $showingSaveConfirmation) {
      Button("Tamam", role: .cancel) {
        // Just dismiss alert, don't close ReviewView
      }
    } message: {
      Text("\(session.capturedCount) fotoğraf başarıyla galerinize kaydedildi.")
    }
    .sheet(
      item: Binding(
        get: { exportedJSONURL.map { IdentifiableURL(url: $0) } },
        set: { exportedJSONURL = $0?.url }
      )
    ) { identifiableURL in
      ActivityViewControllerRepresentable(activityItems: [identifiableURL.url])
    }
    .alert("Export Hatası", isPresented: .constant(exportError != nil)) {
      Button("Tamam", role: .cancel) {
        exportError = nil
      }
    } message: {
      if let error = exportError {
        Text(error)
      }
    }
  }

  private var headerView: some View {
    VStack(spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Fotoğraflarınızı İnceleyin")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)

          Text("\(session.capturedCount)/\(session.totalCount) fotoğraf çekildi")
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))
        }

        Spacer()

        // Layout toggle buttons
        HStack(spacing: 12) {
          // Grid layout toggle
          Button(action: {
            withAnimation {
              showProfessionalGrid.toggle()
            }
          }) {
            Image(systemName: showProfessionalGrid ? "square.grid.2x2.fill" : "square.grid.2x2")
              .font(.title3)
              .foregroundColor(.white.opacity(showProfessionalGrid ? 1.0 : 0.6))
          }

          // Heat map toggle
          Button(action: {
            withAnimation {
              showHeatMap.toggle()
            }
          }) {
            Image(systemName: showHeatMap ? "chart.bar.fill" : "chart.bar")
              .font(.title3)
              .foregroundColor(.white.opacity(showHeatMap ? 1.0 : 0.6))
          }
        }
      }
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
        HStack(spacing: 10) {
          if isSaving {
            ProgressView()
              .tint(.white)
          } else {
            Image(systemName: "square.and.arrow.down")
              .font(.system(size: 22))
            Text("Galeriye Kaydet")
              .font(.system(size: 18))
              .fontWeight(.semibold)
          }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(session.capturedCount > 0 ? Color.green : Color.green.opacity(0.5))
        .foregroundColor(.white)
        .cornerRadius(12)
      }
      .disabled(isSaving || session.capturedCount == 0)

      // Share button
      Button(action: {
        showingShareSheet = true
      }) {
        HStack(spacing: 10) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 22))
          Text("Paylaş")
            .font(.system(size: 18))
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(session.capturedCount > 0 ? Color.blue : Color.blue.opacity(0.5))
        .foregroundColor(.white)
        .cornerRadius(12)
      }
      .disabled(session.capturedCount == 0)

      // Export JSON (for ML/Backend)
      Button(action: {
        exportSessionJSON()
      }) {
        HStack(spacing: 10) {
          if isExportingJSON {
            ProgressView()
              .tint(.white)
          } else {
            Image(systemName: "doc.text")
              .font(.system(size: 22))
            Text("JSON Export (ML)")
              .font(.system(size: 18))
              .fontWeight(.semibold)
          }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(session.capturedCount > 0 ? Color.purple : Color.purple.opacity(0.5))
        .foregroundColor(.white)
        .cornerRadius(12)
      }
      .disabled(session.capturedCount == 0 || isExportingJSON)
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

  private func exportSessionJSON() {
    isExportingJSON = true

    Task {
      do {
        // Create temporary file URL with proper extension
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "pentacapture_\(dateString).json"
        let fileURL = tempDir.appendingPathComponent(filename)

        // Export session as JSON (with metadata, without images)
        try session.saveJSONExport(to: fileURL, includeImages: false)

        // Verify file
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        let fileSize =
          try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int

        print("✅ JSON exported successfully")
        print("📄 Path: \(fileURL.path)")
        print("📄 File exists: \(fileExists)")
        print("📄 File size: \(fileSize ?? 0) bytes")

        // Read and verify JSON content
        if let jsonData = try? Data(contentsOf: fileURL),
          let jsonString = String(data: jsonData, encoding: .utf8)
        {
          print("📄 JSON preview (first 200 chars):")
          print(String(jsonString.prefix(200)))
        }

        await MainActor.run {
          isExportingJSON = false
          // Set URL which will automatically trigger the share sheet
          exportedJSONURL = fileURL
        }
      } catch {
        print("❌ JSON export failed: \(error.localizedDescription)")
        await MainActor.run {
          isExportingJSON = false
          exportError = "JSON export başarısız: \(error.localizedDescription)"
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

/// Basit UIActivityViewController wrapper
struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // No updates needed
  }
}

/// Legacy wrapper for other share sheets
struct ActivityViewController: UIViewControllerRepresentable {
  let activityViewController: UIActivityViewController

  func makeUIViewController(context: Context) -> UIActivityViewController {
    return activityViewController
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // No updates needed
  }
}

/// Identifiable wrapper for URL to use with sheet(item:)
struct IdentifiableURL: Identifiable {
  let id = UUID()
  let url: URL
}
