//
//  MotionService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 11.11.2025.
//

import CoreMotion
import Foundation
import Combine

/// Device orientation data from CoreMotion
struct DeviceOrientation {
    let pitch: Double      // Eğim (yukarı/aşağı) - radyan
    let roll: Double       // Yan yatış (sağa/sola) - radyan
    let yaw: Double        // Rotasyon (dönüş) - radyan
    let gravity: CMAcceleration  // Yerçekimi vektörü
    
    // Derece cinsinden değerler
    var pitchDegrees: Double { pitch * 180.0 / .pi }
    var rollDegrees: Double { roll * 180.0 / .pi }
    var yawDegrees: Double { yaw * 180.0 / .pi }
    
    /// Telefonun yere göre eğimi (0° = yatay, 90° = dik)
    var tiltAngleDegrees: Double {
        // Gravity vector'ü kullanarak telefonun yere göre açısını hesapla
        // gravity.z = -1 → telefon yatay (ekran yukarı)
        // gravity.z = 0 → telefon dik
        let gravityMagnitude = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
        guard gravityMagnitude > 0 else { return 0 }
        
        // Z eksenindeki yerçekimi komponenti telefonun yere göre açısını verir
        let normalizedZ = gravity.z / gravityMagnitude
        let tiltRadians = acos(-normalizedZ) // -1 (yukarı) → 0°, 0 (yatay) → 90°
        return tiltRadians * 180.0 / .pi
    }
    
    /// Telefonun başa göre konumu (vertex ve donor area için)
    /// true = telefon başın üstünde/arkasında (yere dik pozisyon)
    var isVerticalPosition: Bool {
        // Telefon 60° ile 120° arasında eğimliyse "dik" sayılır
        tiltAngleDegrees >= 60 && tiltAngleDegrees <= 120
    }
}

/// Motion tracking errors
enum MotionError: LocalizedError {
    case notAvailable
    case failedToStart
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Hareket sensörleri kullanılamıyor"
        case .failedToStart:
            return "Hareket takibi başlatılamadı"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            return "Bu cihazda gyroscope veya ivmeölçer bulunamadı. Lütfen farklı bir cihaz kullanın."
        case .failedToStart:
            return "Hareket sensörleri başlatılamadı. Lütfen uygulamayı yeniden başlatın."
        }
    }
}

/// Service for tracking device motion using CoreMotion
@MainActor
class MotionService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentOrientation: DeviceOrientation?
    @Published var isTracking = false
    @Published var error: MotionError?
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz
    private var updateCount = 0
    
    // Publisher for orientation updates
    let orientationPublisher = PassthroughSubject<DeviceOrientation, Never>()
    
    // MARK: - Properties
    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }
    
    // MARK: - Initialization
    nonisolated init() {
        // Per Apple SE-0327: Non-async initializers can be nonisolated
        // when they don't access actor-isolated state
        print("🎯 MotionService initialized")
        print("   Device motion available: \(motionManager.isDeviceMotionAvailable)")
    }
    
    // MARK: - Start/Stop
    func startTracking() {
        guard isAvailable else {
            print("❌ Device motion not available")
            error = .notAvailable
            return
        }
        
        guard !isTracking else {
            print("⚠️ Already tracking motion")
            return
        }
        
        print("🚀 Starting CoreMotion tracking...")
        
        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = updateInterval
        
        // Use xArbitraryZVertical reference frame
        // This provides gravity-aligned coordinates (Z axis = vertical)
        // Per Apple docs: Best for measuring relative device orientation
        let referenceFrame = CMAttitudeReferenceFrame.xArbitraryZVertical
        
        // Start device motion updates
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ CoreMotion error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.error = .failedToStart
                    self.isTracking = false
                }
                return
            }
            
            guard let motion = motion else { return }
            
            // Extract orientation from CMDeviceMotion
            let orientation = DeviceOrientation(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw,
                gravity: motion.gravity
            )
            
            Task { @MainActor in
                self.currentOrientation = orientation
                self.orientationPublisher.send(orientation)
                
                // Log periodically (every 60 updates = ~1 second)
                self.updateCount += 1
                if self.updateCount % 60 == 1 {
                    print("📐 Motion: P=\(String(format: "%.1f°", orientation.pitchDegrees)) R=\(String(format: "%.1f°", orientation.rollDegrees)) Y=\(String(format: "%.1f°", orientation.yawDegrees)) Tilt=\(String(format: "%.1f°", orientation.tiltAngleDegrees))")
                }
            }
        }
        
        isTracking = true
        error = nil
        updateCount = 0
        
        print("✅ CoreMotion tracking started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        print("⏹️ Stopping CoreMotion tracking...")
        motionManager.stopDeviceMotionUpdates()
        isTracking = false
        currentOrientation = nil
        
        print("✅ CoreMotion tracking stopped")
    }
    
    // MARK: - Utility Methods
    
    /// Check if device is at correct angle for a specific capture angle
    func isOrientationValid(for captureAngle: CaptureAngle, tolerance: Double = 15.0) -> Bool {
        guard let orientation = currentOrientation else { return false }
        
        switch captureAngle {
        case .frontFace, .rightProfile, .leftProfile:
            // Face photos: telefon yere paralel olmalı (0° ± tolerance)
            return abs(orientation.tiltAngleDegrees) <= tolerance
            
        case .vertex:
            // Tepe fotoğrafı: telefon başın üstünde (~90° ± tolerance)
            // Ideal: 90°, tolerans: ±20°
            let idealAngle = 90.0
            return abs(orientation.tiltAngleDegrees - idealAngle) <= (tolerance + 5.0)
            
        case .donorArea:
            // Arka donör: telefon başın arkasında, hafif eğimli (60-90° arası)
            // Kullanıcı telefonu ense bölgesine doğru tutuyor
            return orientation.tiltAngleDegrees >= 50 && orientation.tiltAngleDegrees <= 100
        }
    }
    
    /// Get feedback message for current orientation
    func getOrientationFeedback(for captureAngle: CaptureAngle) -> String? {
        guard let orientation = currentOrientation else {
            return "Telefon açısı ölçülemiyor"
        }
        
        switch captureAngle {
        case .frontFace, .rightProfile, .leftProfile:
            // Face photos need horizontal phone
            let tilt = orientation.tiltAngleDegrees
            if tilt > 30 {
                return "Telefonu daha yatay tutun"
            } else if tilt > 15 {
                return "Telefonu biraz daha yatay tutun"
            }
            return nil // Orientation is good
            
        case .vertex:
            // Vertex needs vertical phone above head
            let tilt = orientation.tiltAngleDegrees
            let idealAngle = 90.0
            let error = tilt - idealAngle
            
            if abs(error) <= 15 {
                return nil // Good
            } else if error < -15 {
                return "Telefonu daha dik tutun"
            } else {
                return "Telefonu başınızın tam üstüne getirin"
            }
            
        case .donorArea:
            // Donor area needs phone behind head
            let tilt = orientation.tiltAngleDegrees
            if tilt < 50 {
                return "Telefonu daha dik tutun"
            } else if tilt > 100 {
                return "Telefonu biraz daha yatay tutun"
            }
            return nil // Good
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Note: deinit is nonisolated, so we can't check @MainActor properties
        // Always stop motion updates on cleanup to be safe
        motionManager.stopDeviceMotionUpdates()
    }
}

