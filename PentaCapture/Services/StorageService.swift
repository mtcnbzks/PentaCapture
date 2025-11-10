//
//  StorageService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Photos
import UIKit
import Combine

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
            requestAuthorization()
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
                    self?.authorizationStatus = status
                    self?.isAuthorized = (status == .authorized || status == .limited)
                    
                    if !self!.isAuthorized {
                        self?.error = .unauthorized
                    }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    self?.isAuthorized = (status == .authorized)
                    
                    if !self!.isAuthorized {
                        self?.error = .unauthorized
                    }
                }
            }
        }
    }
    
    // MARK: - Save Methods
    
    /// Save a single photo to gallery
    func saveToGallery(_ image: UIImage) async throws -> String {
        guard isAuthorized else {
            throw StorageError.unauthorized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var assetIdentifier: String?
            
            photoLibrary.performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9)!, options: nil)
                
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
    
    /// Save multiple photos to gallery as an album
    func saveSessionToGallery(_ session: CaptureSession, albumName: String = "PentaCapture") async throws -> [String] {
        guard isAuthorized else {
            throw StorageError.unauthorized
        }
        
        var identifiers: [String] = []
        
        // Get or create album
        let album = try await getOrCreateAlbum(named: albumName)
        
        // Save each photo
        for photo in session.capturedPhotos {
            guard let image = photo.image else { continue }
            
            let identifier = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var assetIdentifier: String?
                
                photoLibrary.performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9)!, options: nil)
                    
                    // Add metadata
                    creationRequest.creationDate = photo.timestamp
                    
                    assetIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
                    
                    // Add to album
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                       let placeholder = creationRequest.placeholderForCreatedAsset {
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
        }
        
        return identifiers
    }
    
    // MARK: - Album Management
    
    /// Get existing album or create new one
    private func getOrCreateAlbum(named albumName: String) async throws -> PHAssetCollection {
        // Check if album exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collection.firstObject {
            return album
        }
        
        // Create new album
        return try await withCheckedThrowingContinuation { continuation in
            var albumPlaceholder: PHObjectPlaceholder?
            
            photoLibrary.performChanges {
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
            } completionHandler: { success, error in
                if success, let placeholder = albumPlaceholder {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
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
        let pentaCaptureAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject
        
        let pentaCaptureCount = pentaCaptureAlbum.map { album in
            PHAsset.fetchAssets(in: album, options: nil).count
        } ?? 0
        
        return (allPhotos.count, pentaCaptureCount)
    }
}

// MARK: - Local Storage Extension
extension StorageService {
    /// Save session to UserDefaults for quick access
    func saveSessionLocally(_ session: CaptureSession) {
        guard let data = exportSession(session) else { return }
        
        UserDefaults.standard.set(data, forKey: "lastCaptureSession")
        UserDefaults.standard.set(session.sessionId.uuidString, forKey: "lastSessionId")
        UserDefaults.standard.set(session.startTime, forKey: "lastSessionDate")
    }
    
    /// Load last session from UserDefaults
    func loadLastSession() -> CaptureSession? {
        guard let data = UserDefaults.standard.data(forKey: "lastCaptureSession"),
              let photos = try? importSession(data) else {
            return nil
        }
        
        let session = CaptureSession()
        // Directly set photos to prevent multiple addPhoto calls that change currentAngle
        session.capturedPhotos = photos
        
        // Determine current angle and completion status
        if photos.count >= CaptureAngle.allCases.count {
            session.isComplete = true
        } else if let lastPhoto = photos.last,
                  let nextAngle = lastPhoto.angle.next {
            session.currentAngle = nextAngle
        }
        
        return session
    }
    
    /// Clear locally stored session
    func clearLocalSession() {
        UserDefaults.standard.removeObject(forKey: "lastCaptureSession")
        UserDefaults.standard.removeObject(forKey: "lastSessionId")
        UserDefaults.standard.removeObject(forKey: "lastSessionDate")
    }
}

