//
//  FaceTrackingService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import ARKit
import Combine
import simd

/// ARKit'ten gelen yüz pozisyonu bilgisi
struct HeadPose {
    let yaw: Double      // Yüz rotasyonu (sol/sağ) - radyan
    let pitch: Double    // Yüz eğimi (yukarı/aşağı) - radyan
    let roll: Double     // Yüz yatışı (yan eğim) - radyan
    let transform: simd_float4x4  // Tam transform matrisi
    let position: simd_float3     // 3D pozisyon (x, y, z) - kamera koordinatlarında
    
    // Derece cinsinden değerler
    var yawDegrees: Double { yaw * 180.0 / .pi }
    var pitchDegrees: Double { pitch * 180.0 / .pi }
    var rollDegrees: Double { roll * 180.0 / .pi }
    
    // Yüzün merkeze olan uzaklığı (normalized, 0.0 = merkez)
    // x: yatay offset (-left, +right), y: dikey offset (-down, +up)
    var centerOffset: CGPoint {
        // ARKit position: x = right, y = up, z = forward (camera space)
        // Normalize edilmiş değerler (kabaca 0.3 metre = tam ekran)
        let normalizedX = CGFloat(position.x / 0.15) // ±0.15m ≈ tam ekran genişliği
        let normalizedY = CGFloat(position.y / 0.2)  // ±0.2m ≈ tam ekran yüksekliği
        return CGPoint(x: normalizedX, y: normalizedY)
    }
}

/// Face tracking hataları
enum FaceTrackingError: LocalizedError {
    case notSupported
    case sessionFailed
    case noFaceDetected
    
    var errorDescription: String? {
        switch self {
        case .notSupported: return "Bu cihazda yüz takibi desteklenmiyor"
        case .sessionFailed: return "ARSession başlatılamadı"
        case .noFaceDetected: return "Yüz tespit edilemedi"
        }
    }
}

/// ARKit tabanlı yüz takip servisi
@MainActor
class FaceTrackingService: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var currentHeadPose: HeadPose?
    @Published var error: FaceTrackingError?
    @Published var trackingState: String = "Not Started"
    
    nonisolated(unsafe) let isSupported: Bool
    let arSession = ARSession() // Public - ARSCNView için gerekli
    private var frameCount = 0
    
    override nonisolated init() {
        self.isSupported = ARFaceTrackingConfiguration.isSupported
        super.init()
        
        Task { @MainActor in
            print("🎯 FaceTrackingService initialized")
            print("   ARKit supported: \(self.isSupported)")
            print("   Device: \(UIDevice.current.model)")
        }
    }
    
    func startTracking() {
        guard isSupported else {
            print("❌ ARKit not supported on this device")
            error = .notSupported
            return
        }
        
        guard !isTracking else {
            print("⚠️ Already tracking")
            return
        }
        
        print("🚀 Starting ARKit Face Tracking...")

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        configuration.maximumNumberOfTrackedFaces = 1
        // CRITICAL: Use .camera alignment for device-relative face orientation
        // This makes face angles independent of phone tilt (gravity)
        configuration.worldAlignment = .camera

        print("📋 Configuration:")
        print("   - worldAlignment: .camera (device-relative)")
        print("   - maxFaces: 1")
        
        arSession.delegate = self
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        isTracking = true
        error = nil
        frameCount = 0
        trackingState = "Starting..."
        
        print("✅ ARSession started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        arSession.pause()
        isTracking = false
        currentHeadPose = nil
    }
    
    // Extract HeadPose from ARFaceAnchor
    // With worldAlignment = .camera, transform is already camera-relative
    nonisolated private func extractHeadPose(from faceAnchor: ARFaceAnchor) -> HeadPose {
        let eulerAngles = faceAnchor.transform.eulerAngles
        
        // Extract 3D position from transform matrix (column 3 = translation)
        let position = simd_float3(
            faceAnchor.transform.columns.3.x,
            faceAnchor.transform.columns.3.y,
            faceAnchor.transform.columns.3.z
        )

        // Axis mapping for front camera + .camera alignment:
        // - yaw (left/right turn) → eulerAngles.x (negated for mirror)
        // - pitch (up/down tilt) → eulerAngles.y
        // - roll (side-to-side tilt) → eulerAngles.z
        return HeadPose(
            yaw: -Double(eulerAngles.x),
            pitch: Double(eulerAngles.y),
            roll: Double(eulerAngles.z),
            transform: faceAnchor.transform,
            position: position
        )
    }
}

// MARK: - ARSessionDelegate
extension FaceTrackingService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            self.frameCount += 1

            // Log ilk 10 frame ve sonra her 30 frame'de bir
            let shouldLog = self.frameCount <= 10 || self.frameCount % 30 == 0

            if shouldLog {
                print("📹 Frame #\(self.frameCount) - Anchors: \(frame.anchors.count)")
            }
        }

        guard let faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            Task { @MainActor in
                if self.frameCount <= 20 {
                    print("⚠️ No face anchor in frame #\(self.frameCount)")
                }
                self.currentHeadPose = nil
                self.trackingState = "No Face Detected"
            }
            return
        }

        // With .camera worldAlignment, face is already in camera space
        // No need to pass camera transform - it's automatic!
        let headPose = extractHeadPose(from: faceAnchor)

        Task { @MainActor in
            self.currentHeadPose = headPose
            self.trackingState = faceAnchor.isTracked ? "Tracking" : "Not Tracked"

            // İlk face bulunduğunda log
            if self.frameCount <= 10 {
                print("✅ Face found! Yaw: \(String(format: "%.1f°", headPose.yawDegrees)) Pitch: \(String(format: "%.1f°", headPose.pitchDegrees)) Roll: \(String(format: "%.1f°", headPose.rollDegrees))")
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            let stateDescription: String
            let reasonDescription: String
            
            switch camera.trackingState {
            case .normal:
                stateDescription = "Normal ✅"
                reasonDescription = "Tracking is working properly"
            case .notAvailable:
                stateDescription = "Not Available ❌"
                reasonDescription = "Tracking is not available"
            case .limited(let reason):
                stateDescription = "Limited ⚠️"
                switch reason {
                case .initializing:
                    reasonDescription = "Initializing..."
                case .relocalizing:
                    reasonDescription = "Relocalizing..."
                case .excessiveMotion:
                    reasonDescription = "Too much motion"
                case .insufficientFeatures:
                    reasonDescription = "Not enough features"
                @unknown default:
                    reasonDescription = "Unknown reason"
                }
            }
            
            self.trackingState = stateDescription
            print("📊 Tracking State: \(stateDescription) - \(reasonDescription)")
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ ARSession failed: \(error.localizedDescription)")
        
        Task { @MainActor in
            self.error = .sessionFailed
            self.isTracking = false
            self.trackingState = "Failed"
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        print("⏸️ ARSession interrupted")
        
        Task { @MainActor in
            self.isTracking = false
            self.trackingState = "Interrupted"
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        print("▶️ ARSession interruption ended")
        
        Task { @MainActor in
            if self.isSupported {
                self.startTracking()
            }
        }
    }
}
