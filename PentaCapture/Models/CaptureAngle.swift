//
//  CaptureAngle.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Foundation

/// 5 critical angles for hair/head photography
enum CaptureAngle: Int, CaseIterable, Identifiable, Codable {
  case frontFace = 0
  case rightProfile = 1
  case leftProfile = 2
  case vertex = 3
  case donorArea = 4

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .frontFace: "Ön Yüz"
    case .rightProfile: "Sağ Profil"
    case .leftProfile: "Sol Profil"
    case .vertex: "Tepe"
    case .donorArea: "Arka Donör"
    }
  }

  var instructions: String {
    switch self {
    case .frontFace: "Yüzünüzü kameraya bakın"
    case .rightProfile: "Başınızı 45° sağa çevirin"
    case .leftProfile: "Başınızı 45° sola çevirin"
    case .vertex: "Telefonu tepe bölgesine tutun"
    case .donorArea: "Telefonu ense bölgesine tutun"
    }
  }

  /// Target pitch angle (degrees) - camera-relative
  var targetPitch: Double {
    switch self {
    case .frontFace, .rightProfile, .leftProfile: 0.0
    case .vertex: 90.0
    case .donorArea: 165.0
    }
  }

  var pitchTolerance: Double {
    switch self {
    case .frontFace, .rightProfile, .leftProfile: 15.0
    case .vertex: 20.0
    case .donorArea: 40.0
    }
  }

  /// Target roll angle - only required for donorArea
  var targetRoll: Double? {
    self == .donorArea ? 180.0 : nil
  }

  var rollTolerance: Double {
    self == .donorArea ? 40.0 : 180.0
  }

  /// Target yaw angle (degrees) for face rotation
  var targetYaw: Double? {
    switch self {
    case .frontFace: 0.0
    case .rightProfile: 45.0
    case .leftProfile: -45.0
    case .vertex, .donorArea: nil
    }
  }

  var yawTolerance: Double {
    switch self {
    case .frontFace, .rightProfile, .leftProfile: 15.0
    default: 45.0
    }
  }

  var symbolName: String {
    switch self {
    case .frontFace: "person.crop.circle"
    case .rightProfile: "arrow.turn.up.right"
    case .leftProfile: "arrow.turn.up.left"
    case .vertex: "arrow.up.circle"
    case .donorArea: "arrow.backward.circle"
    }
  }

  var next: CaptureAngle? {
    CaptureAngle(rawValue: rawValue + 1)
  }
}
