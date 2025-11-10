//
//  CaptureSession.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Foundation
import UIKit
import Combine

/// Represents a single captured photo with metadata
struct CapturedPhoto: Identifiable, Codable {
    let id: UUID
    let angle: CaptureAngle
    let timestamp: Date
    let imageData: Data
    
    init(id: UUID = UUID(), angle: CaptureAngle, timestamp: Date = Date(), image: UIImage) {
        self.id = id
        self.angle = angle
        self.timestamp = timestamp
        self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
    }
    
    /// Get UIImage from stored data
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, angle, timestamp, imageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let angleRawValue = try container.decode(Int.self, forKey: .angle)
        angle = CaptureAngle(rawValue: angleRawValue) ?? .frontFace
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageData = try container.decode(Data.self, forKey: .imageData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(angle.rawValue, forKey: .angle)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(imageData, forKey: .imageData)
    }
}

/// Manages the state of a capture session
class CaptureSession: ObservableObject {
    @Published var currentAngle: CaptureAngle
    @Published var capturedPhotos: [CapturedPhoto]
    @Published var isComplete: Bool
    
    let sessionId: UUID
    let startTime: Date
    
    init() {
        self.sessionId = UUID()
        self.startTime = Date()
        self.currentAngle = .frontFace
        self.capturedPhotos = []
        self.isComplete = false
    }
    
    /// Add a captured photo to the session
    func addPhoto(_ photo: CapturedPhoto) {
        // Prevent duplicate photos for the same angle
        // Remove any existing photo for this angle first
        capturedPhotos.removeAll { $0.angle == photo.angle }
        
        // Add the new photo
        capturedPhotos.append(photo)
        print("📸 Photo added for \(photo.angle.title). Total: \(capturedPhotos.count)")
        
        // Move to next angle or mark complete
        if let nextAngle = currentAngle.next {
            print("➡️ Moving to next angle: \(nextAngle.title)")
            currentAngle = nextAngle
        } else {
            print("✅ All angles captured! Session complete.")
            isComplete = true
        }
    }
    
    /// Check if a specific angle has been captured
    func hasPhoto(for angle: CaptureAngle) -> Bool {
        capturedPhotos.contains { $0.angle == angle }
    }
    
    /// Get photo for a specific angle
    func photo(for angle: CaptureAngle) -> CapturedPhoto? {
        capturedPhotos.first { $0.angle == angle }
    }
    
    /// Progress as percentage (0.0 to 1.0)
    var progress: Double {
        Double(capturedPhotos.count) / Double(CaptureAngle.allCases.count)
    }
    
    /// Number of photos captured
    var capturedCount: Int {
        capturedPhotos.count
    }
    
    /// Total number of photos needed
    var totalCount: Int {
        CaptureAngle.allCases.count
    }
    
    /// Reset session to start over
    func reset() {
        currentAngle = .frontFace
        capturedPhotos.removeAll()
        isComplete = false
    }
    
    /// Retake a specific angle
    func retakeAngle(_ angle: CaptureAngle) {
        capturedPhotos.removeAll { $0.angle == angle }
        currentAngle = angle
        isComplete = false
    }
}

