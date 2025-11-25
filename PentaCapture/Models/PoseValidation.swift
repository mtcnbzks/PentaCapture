//
//  PoseValidation.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import CoreGraphics
import Foundation

enum ValidationStatus: Equatable {
  case invalid
  case adjusting(progress: Double)
  case valid
  case locked

  var isValid: Bool {
    switch self {
    case .valid, .locked: true
    default: false
    }
  }

  var progress: Double {
    switch self {
    case .invalid: 0.0
    case .adjusting(let p): p
    case .valid: 0.95
    case .locked: 1.0
    }
  }
}

struct OrientationValidation {
  let status: ValidationStatus
  let currentPitch: Double
  let targetPitch: Double
  let pitchError: Double
  let currentYaw: Double?
  let targetYaw: Double?
  let yawError: Double?
  let currentRoll: Double?
  let targetRoll: Double?
  let rollError: Double?

  var feedbackMessage: String {
    switch status {
    case .invalid:
      if let rollError, rollError > 40 {
        return "Telefonu ters tutun (baş aşağı)"
      }
      if let yawError, let targetYaw, abs(yawError) > 10 {
        if yawError > 0 {
          return targetYaw > 0 ? "Başınızı daha fazla sağa çevirin" : "Başınızı daha az sağa çevirin"
        } else {
          return targetYaw < 0 ? "Başınızı daha fazla sola çevirin" : "Başınızı daha az sola çevirin"
        }
      }
      return pitchError > 0 ? "Telefonu daha yukarı kaldırın" : "Telefonu daha aşağı indirin"
    case .adjusting: return "Açıyı ayarlayın..."
    case .valid: return "Açı doğru, sabit tutun"
    case .locked: return "Mükemmel!"
    }
  }
}

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
      if abs(centerOffset.x) > abs(centerOffset.y) {
        return centerOffset.x > 0 ? "Yüzünüzü daha sola alın" : "Yüzünüzü daha sağa alın"
      } else {
        return centerOffset.y > 0 ? "Yüzünüzü daha aşağı alın" : "Yüzünüzü daha yukarı alın"
      }
    case .adjusting: return "Yüzünüzü merkeze getirin..."
    case .valid: return "Pozisyon iyi"
    case .locked: return "Kilitlendi!"
    }
  }
}

struct PoseValidation {
  let orientationValidation: OrientationValidation
  let detectionValidation: DetectionValidation
  let isStable: Bool
  let stabilityDuration: TimeInterval

  static let requiredStabilityDuration: TimeInterval = 0.5

  var overallStatus: ValidationStatus {
    guard orientationValidation.status.isValid && detectionValidation.status.isValid else {
      let combinedProgress = (orientationValidation.status.progress + detectionValidation.status.progress) / 2.0
      return combinedProgress < 0.1 ? .invalid : .adjusting(progress: combinedProgress)
    }
    return isStable && stabilityDuration >= Self.requiredStabilityDuration ? .locked : .valid
  }

  var isReadyForCapture: Bool { overallStatus == .locked }
  var progress: Double { overallStatus.progress }

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

enum ValidationMetrics {
  static func determineOrientationStatus(
    currentAngle: Double,
    targetAngle: Double,
    tolerance: Double
  ) -> ValidationStatus {
    let error = abs(currentAngle - targetAngle)
    guard error > tolerance else { return .valid }
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

    if let currentYaw, let targetYaw {
      let yawError = abs(currentYaw - targetYaw)
      yawValid = yawError <= yawTolerance
      yawProgress = max(0, 1.0 - (yawError / (yawTolerance * 3)))
    } else if requiresYaw {
      yawValid = false
      yawProgress = 0.0
    }

    guard !pitchValid || !yawValid else { return .valid }
    let overallProgress = (pitchProgress + yawProgress) / 2.0
    return overallProgress < 0.2 ? .invalid : .adjusting(progress: overallProgress)
  }
}
