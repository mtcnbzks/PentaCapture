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
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Fotoğraflarınız")
          .font(.system(size: 20, weight: .semibold, design: .rounded))
          .foregroundColor(.white)

        Text("\(session.capturedCount)/\(session.totalCount) fotoğraf")
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.white.opacity(0.6))
      }

      Spacer()

      // Layout toggle buttons - minimal
      HStack(spacing: 8) {
        // Grid layout toggle
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            showProfessionalGrid.toggle()
          }
        }) {
          Image(systemName: showProfessionalGrid ? "square.grid.2x2.fill" : "square.grid.2x2")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white.opacity(showProfessionalGrid ? 0.9 : 0.5))
            .frame(width: 40, height: 40)
            .background(
              Circle()
                .fill(showProfessionalGrid ? Color.white.opacity(0.1) : Color.clear)
            )
        }

        // Heat map toggle
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            showHeatMap.toggle()
          }
        }) {
          Image(systemName: showHeatMap ? "chart.bar.fill" : "chart.bar")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white.opacity(showHeatMap ? 0.9 : 0.5))
            .frame(width: 40, height: 40)
            .background(
              Circle()
                .fill(showHeatMap ? Color.white.opacity(0.1) : Color.clear)
            )
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity)
    .background(Color.black.opacity(0.2))
  }

  private var actionButtons: some View {
    VStack(spacing: 10) {
      // Save to gallery button - primary
      Button(action: {
        saveToGallery()
      }) {
        HStack(spacing: 8) {
          if isSaving {
            ProgressView()
              .controlSize(.small)
              .tint(Color(red: 0.1, green: 0.1, blue: 0.15))
          } else {
            Image(systemName: "square.and.arrow.down")
              .font(.system(size: 15, weight: .medium))
            Text("Galeriye Kaydet")
              .font(.system(size: 15, weight: .semibold))
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          session.capturedCount > 0
            ? Color.white : Color.white.opacity(0.3)
        )
        .foregroundColor(
          session.capturedCount > 0
            ? Color(red: 0.1, green: 0.1, blue: 0.15) : Color.white.opacity(0.5)
        )
        .cornerRadius(12)
      }
      .disabled(isSaving || session.capturedCount == 0)

      HStack(spacing: 10) {
        // Share button
        Button(action: {
          showingShareSheet = true
        }) {
          HStack(spacing: 6) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 14, weight: .medium))
            Text("Paylaş")
              .font(.system(size: 14, weight: .medium))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            session.capturedCount > 0
              ? Color.white.opacity(0.15) : Color.white.opacity(0.05)
          )
          .foregroundColor(
            session.capturedCount > 0
              ? .white.opacity(0.9) : .white.opacity(0.4)
          )
          .cornerRadius(10)
        }
        .disabled(session.capturedCount == 0)

        // Export JSON (for ML/Backend)
        Button(action: {
          exportSessionJSON()
        }) {
          HStack(spacing: 6) {
            if isExportingJSON {
              ProgressView()
                .controlSize(.small)
                .tint(.white)
            } else {
              Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .medium))
              Text("JSON")
                .font(.system(size: 14, weight: .medium))
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            session.capturedCount > 0
              ? Color.white.opacity(0.15) : Color.white.opacity(0.05)
          )
          .foregroundColor(
            session.capturedCount > 0
              ? .white.opacity(0.9) : .white.opacity(0.4)
          )
          .cornerRadius(10)
        }
        .disabled(session.capturedCount == 0 || isExportingJSON)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Color.black.opacity(0.4))
  }

  private func saveToGallery() {
    // Check if we need to request permission first
    if !storageService.isAuthorized {
      // Request permission - this only happens once
      // The completion handler ensures we only proceed if authorized
      storageService.requestAuthorization { authorized in
        if authorized {
          // Permission granted, proceed with save
          self.performSave()
        } else {
          // Permission denied - user will see error from StorageService
          print("⚠️ Gallery permission not granted")
        }
      }
    } else {
      // Already authorized, proceed with save
      performSave()
    }
  }

  private func performSave() {
    isSaving = true

    Task {
      do {
        _ = try await storageService.saveSessionToGallery(session)
        await MainActor.run {
          isSaving = false
          showingSaveConfirmation = true
          onSaveToGallery()  // Notify parent
        }
      } catch {
        await MainActor.run {
          isSaving = false
          // Error will be shown via StorageService.error
          print("❌ Failed to save to gallery: \(error.localizedDescription)")
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

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label).font(.subheadline).foregroundColor(.white.opacity(0.7))
      Spacer()
      Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
    }
  }
}

struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ActivityViewController: UIViewControllerRepresentable {
  let activityViewController: UIActivityViewController

  func makeUIViewController(context: Context) -> UIActivityViewController { activityViewController }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
  let id = UUID()
  let url: URL
}
