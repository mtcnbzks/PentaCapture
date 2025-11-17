//
//  StorageService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Combine
import Photos
import UIKit

/// Errors that can occur during storage operations
enum StorageError: LocalizedError {
  case unauthorized
  case saveFailed
  case loadFailed
  case invalidData

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      return "Fotoğraf galerisine erişim izni verilmedi."
    case .saveFailed:
      return "Fotoğraf kaydedilemedi."
    case .loadFailed:
      return "Fotoğraf yüklenemedi."
    case .invalidData:
      return "Geçersiz fotoğraf verisi."
    }
  }
}

/// Service responsible for saving photos to gallery and managing local storage
class StorageService: ObservableObject {
  // MARK: - Published Properties
  @Published var isAuthorized = false
  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
  @Published var error: StorageError?

  // MARK: - Private Properties
  private let photoLibrary = PHPhotoLibrary.shared()

  // MARK: - Initialization
  init() {
    checkAuthorization()
  }

  // MARK: - Authorization
  private func checkAuthorization() {
    let status: PHAuthorizationStatus

    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }

    authorizationStatus = status

    switch status {
    case .authorized, .limited:
      isAuthorized = true
    case .notDetermined:
      // DON'T request automatically - only request when user explicitly tries to save
      isAuthorized = false
    case .denied, .restricted:
      isAuthorized = false
      error = .unauthorized
    @unknown default:
      isAuthorized = false
    }
  }

  func requestAuthorization() {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.authorizationStatus = status
          self.isAuthorized = (status == .authorized || status == .limited)

          if !self.isAuthorized {
            self.error = .unauthorized
          }
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { [weak self] status in
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.authorizationStatus = status
          self.isAuthorized = (status == .authorized)

          if !self.isAuthorized {
            self.error = .unauthorized
          }
        }
      }
    }
  }

  // MARK: - Save Methods

  /// Save a single photo to gallery
  /// Note: Photos are already captured in HEIC format by CameraService,
  /// so we just save them directly without additional compression
  func saveToGallery(_ image: UIImage) async throws -> String {
    guard isAuthorized else {
      throw StorageError.unauthorized
    }

    return try await withCheckedThrowingContinuation { continuation in
      var assetIdentifier: String?

      // Save as HEIC for optimal storage
      // Use high quality since camera already captured in HEIC format
      guard let imageData = getImageData(from: image) else {
        continuation.resume(throwing: StorageError.invalidData)
        return
      }

      photoLibrary.performChanges {
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .photo, data: imageData, options: nil)

        assetIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
      } completionHandler: { success, error in
        if success, let identifier = assetIdentifier {
          continuation.resume(returning: identifier)
        } else {
          continuation.resume(throwing: error ?? StorageError.saveFailed)
        }
      }
    }
  }

  /// Get image data in best available format
  /// Prefers HEIC (already captured in this format), falls back to JPEG
  private func getImageData(from image: UIImage) -> Data? {
    // First try HEIC conversion (preserves original HEIC format)
    if #available(iOS 11.0, *),
      let heicData = image.heicData(compressionQuality: 0.9)
    {
      print("💾 Saving photo in HEIC format")
      return heicData
    }

    // Fallback to high-quality JPEG
    print("💾 Saving photo in JPEG format (fallback)")
    return image.jpegData(compressionQuality: 0.9)
  }

  /// Save multiple photos to gallery as an album
  func saveSessionToGallery(_ session: CaptureSession, albumName: String = "PentaCapture")
    async throws -> [String]
  {
    guard isAuthorized else {
      throw StorageError.unauthorized
    }

    var identifiers: [String] = []

    // Get or create album
    let album = try await getOrCreateAlbum(named: albumName)

    // Save each photo (already in HEIC format from camera)
    for photo in session.capturedPhotos {
      guard let image = photo.image else { continue }

      // Get image data (preserves HEIC format from camera)
      guard let imageData = getImageData(from: image) else {
        print("⚠️ Failed to get image data for angle: \(photo.angle.title)")
        continue
      }

      let identifier = try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<String, Error>) in
        var assetIdentifier: String?

        photoLibrary.performChanges {
          let creationRequest = PHAssetCreationRequest.forAsset()
          creationRequest.addResource(with: .photo, data: imageData, options: nil)

          // Add metadata
          creationRequest.creationDate = photo.timestamp

          assetIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier

          // Add to album
          if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
            let placeholder = creationRequest.placeholderForCreatedAsset
          {
            albumChangeRequest.addAssets([placeholder] as NSArray)
          }
        } completionHandler: { success, error in
          if success, let identifier = assetIdentifier {
            continuation.resume(returning: identifier)
          } else {
            continuation.resume(throwing: error ?? StorageError.saveFailed)
          }
        }
      }

      identifiers.append(identifier)
      print("✅ Saved photo to gallery (HEIC): \(photo.angle.title)")
    }

    return identifiers
  }

  // MARK: - Album Management

  /// Get existing album or create new one
  private func getOrCreateAlbum(named albumName: String) async throws -> PHAssetCollection {
    // Check if album exists
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
    let collection = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .any, options: fetchOptions)

    if let album = collection.firstObject {
      return album
    }

    // Create new album
    return try await withCheckedThrowingContinuation { continuation in
      var albumPlaceholder: PHObjectPlaceholder?

      photoLibrary.performChanges {
        let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
          withTitle: albumName)
        albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
      } completionHandler: { success, error in
        if success, let placeholder = albumPlaceholder {
          let fetchResult = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
          if let album = fetchResult.firstObject {
            continuation.resume(returning: album)
          } else {
            continuation.resume(throwing: StorageError.saveFailed)
          }
        } else {
          continuation.resume(throwing: error ?? StorageError.saveFailed)
        }
      }
    }
  }

  // MARK: - Export Methods

  /// Export session as a data package
  func exportSession(_ session: CaptureSession) -> Data? {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    do {
      let data = try encoder.encode(session.capturedPhotos)
      return data
    } catch {
      print("Failed to encode session: \(error.localizedDescription)")
      return nil
    }
  }

  /// Import session from data
  func importSession(_ data: Data) throws -> [CapturedPhoto] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      let photos = try decoder.decode([CapturedPhoto].self, from: data)
      return photos
    } catch {
      throw StorageError.loadFailed
    }
  }

  // MARK: - Helper Methods

  /// Share photos using UIActivityViewController
  func createShareSheet(for session: CaptureSession) -> UIActivityViewController? {
    let images = session.capturedPhotos.compactMap { $0.image }
    guard !images.isEmpty else { return nil }

    let activityVC = UIActivityViewController(
      activityItems: images,
      applicationActivities: nil
    )

    return activityVC
  }

  /// Get photo library usage statistics
  func getStorageStats() async -> (totalPhotos: Int, pentaCapturePhotos: Int) {
    let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)

    // Count photos in PentaCapture album
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", "PentaCapture")
    let pentaCaptureAlbum = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .any, options: fetchOptions
    ).firstObject

    let pentaCaptureCount =
      pentaCaptureAlbum.map { album in
        PHAsset.fetchAssets(in: album, options: nil).count
      } ?? 0

    return (allPhotos.count, pentaCaptureCount)
  }
}

// MARK: - Cleanup
extension StorageService {
  /// Clean up old UserDefaults data that was causing memory issues
  /// This removes the large photo data (20MB+) that was incorrectly stored in UserDefaults
  func cleanupOldUserDefaultsData() {
    // Remove old session data that exceeded UserDefaults 4MB limit
    UserDefaults.standard.removeObject(forKey: "lastCaptureSession")
    UserDefaults.standard.removeObject(forKey: "lastSessionId")
    UserDefaults.standard.removeObject(forKey: "lastSessionDate")
    print("🧹 Cleaned up old UserDefaults session data")
  }
}

// MARK: - UIImage HEIC Extension
extension UIImage {
  /// Convert UIImage to HEIC format data with preserved orientation
  /// HEIC provides better compression than JPEG (~50% smaller file size)
  /// Note: Camera captures in HEIC format, this is for preserving that format
  @available(iOS 11.0, *)
  func heicData(compressionQuality: CGFloat = 0.9) -> Data? {
    guard let mutableData = CFDataCreateMutable(nil, 0),
      let destination = CGImageDestinationCreateWithData(
        mutableData, "public.heic" as CFString, 1, nil),
      let cgImage = self.cgImage
    else {
      return nil
    }

    // CRITICAL: Preserve orientation metadata
    // Convert UIImage.Orientation to CGImagePropertyOrientation value
    let orientationValue = self.cgImagePropertyOrientation

    // High quality with orientation metadata preserved
    let options: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: compressionQuality,
      kCGImagePropertyOrientation: orientationValue,
    ]

    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    return mutableData as Data
  }

  /// Convert UIImage.Orientation to CGImagePropertyOrientation raw value
  /// This ensures orientation is preserved when saving to HEIC/JPEG
  private var cgImagePropertyOrientation: UInt32 {
    switch self.imageOrientation {
    case .up: return 1
    case .upMirrored: return 2
    case .down: return 3
    case .downMirrored: return 4
    case .leftMirrored: return 5
    case .right: return 6
    case .rightMirrored: return 7
    case .left: return 8
    @unknown default: return 1
    }
  }
}
