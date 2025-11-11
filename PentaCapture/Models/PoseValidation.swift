//
//  PoseValidation.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import CoreGraphics
import Foundation

/// Validasyon durumu
enum ValidationStatus: Equatable {
  case invalid
  case adjusting(progress: Double)
  case valid
  case locked

  var isValid: Bool {
    if case .valid = self { return true }
    if case .locked = self { return true }
    return false
  }

  var progress: Double {
    switch self {
    case .invalid: return 0.0
    case .adjusting(let progress): return progress
    case .valid: return 0.95
    case .locked: return 1.0
    }
  }
}

/// Yönelim validasyonu
struct OrientationValidation {
  let status: ValidationStatus
  let currentPitch: Double
  let targetPitch: Double
  let pitchError: Double
  let currentYaw: Double?
  let targetYaw: Double?
  let yawError: Double?

  var feedbackMessage: String {
    switch status {
    case .invalid:
      if let yawError = yawError, let targetYaw = targetYaw, abs(yawError) > 10 {
        if yawError > 0 {
          return targetYaw > 0
            ? "Başınızı daha fazla sağa çevirin" : "Başınızı daha az sağa çevirin"
        } else {
          return targetYaw < 0
            ? "Başınızı daha fazla sola çevirin" : "Başınızı daha az sola çevirin"
        }
      }
      return pitchError > 0 ? "Telefonu daha yukarı kaldırın" : "Telefonu daha aşağı indirin"
    case .adjusting: return "Açıyı ayarlayın..."
    case .valid: return "Açı doğru, sabit tutun"
    case .locked: return "Mükemmel!"
    }
  }
}

/// Tespit validasyonu
struct DetectionValidation {
  let status: ValidationStatus
  let boundingBox: CGRect?
  let size: Double
  let centerOffset: CGPoint
  let isDetected: Bool

  var feedbackMessage: String {
    guard isDetected else { return "Yüz tespit edilemedi" }

    switch status {
    case .invalid:
      // Yönlendirme mesajı (merkeze yaklaştır)
      if abs(centerOffset.x) > abs(centerOffset.y) {
        return centerOffset.x > 0 ? "Yüzünüzü daha sola alın" : "Yüzünüzü daha sağa alın"
      } else {
        return centerOffset.y > 0 ? "Yüzünüzü daha aşağı alın" : "Yüzünüzü daha yukarı alın"
      }
    case .adjusting:
      return "Yüzünüzü merkeze getirin..."
    case .valid:
      return "Pozisyon iyi"
    case .locked:
      return "Kilitlendi!"
    }
  }
}

/// Genel pose validasyonu
struct PoseValidation {
  let orientationValidation: OrientationValidation
  let detectionValidation: DetectionValidation
  let isStable: Bool
  let stabilityDuration: TimeInterval

  static let requiredStabilityDuration: TimeInterval = 0.5

  var overallStatus: ValidationStatus {
    guard orientationValidation.status.isValid && detectionValidation.status.isValid else {
      let orientProgress = orientationValidation.status.progress
      let detectionProgress = detectionValidation.status.progress
      let combinedProgress = (orientProgress + detectionProgress) / 2.0

      if combinedProgress < 0.1 { return .invalid }
      return .adjusting(progress: combinedProgress)
    }

    if isStable && stabilityDuration >= Self.requiredStabilityDuration {
      return .locked
    }
    return .valid
  }

  var isReadyForCapture: Bool {
    overallStatus == .locked
  }

  var progress: Double {
    overallStatus.progress
  }

  var primaryFeedback: String {
    switch overallStatus {
    case .locked: return "Hazır!"
    case .valid: return "Sabit tutun..."
    case .adjusting:
      return orientationValidation.status.progress < detectionValidation.status.progress
        ? orientationValidation.feedbackMessage
        : detectionValidation.feedbackMessage
    case .invalid:
      return !orientationValidation.status.isValid
        ? orientationValidation.feedbackMessage
        : detectionValidation.feedbackMessage
    }
  }
}

/// Validasyon metrikleri hesaplayıcı
struct ValidationMetrics {
  static func determineOrientationStatus(
    currentAngle: Double,
    targetAngle: Double,
    tolerance: Double
  ) -> ValidationStatus {
    let error = abs(currentAngle - targetAngle)
    if error <= tolerance { return .valid }

    let progress = max(0, 1.0 - (error / (tolerance * 3)))
    return progress < 0.2 ? .invalid : .adjusting(progress: progress)
  }

  static func determineOrientationStatusWithYaw(
    currentPitch: Double,
    targetPitch: Double,
    pitchTolerance: Double,
    currentYaw: Double?,
    targetYaw: Double?,
    yawTolerance: Double
  ) -> ValidationStatus {
    let pitchError = abs(currentPitch - targetPitch)
    let pitchValid = pitchError <= pitchTolerance
    let pitchProgress = max(0, 1.0 - (pitchError / (pitchTolerance * 3)))

    let requiresYaw = targetYaw != nil
    var yawValid = !requiresYaw
    var yawProgress = requiresYaw ? 0.0 : 1.0

    if let currentYaw = currentYaw, let targetYaw = targetYaw {
      let yawError = abs(currentYaw - targetYaw)
      yawValid = yawError <= yawTolerance
      yawProgress = max(0, 1.0 - (yawError / (yawTolerance * 3)))
    } else if requiresYaw {
      yawValid = false
      yawProgress = 0.0
    }

    if pitchValid && yawValid { return .valid }

    let overallProgress = (pitchProgress + yawProgress) / 2.0
    return overallProgress < 0.2 ? .invalid : .adjusting(progress: overallProgress)
  }
}
