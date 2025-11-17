//
//  CaptureAngle.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import Foundation

/// Saç/baş fotoğrafı için 5 kritik açı
enum CaptureAngle: Int, CaseIterable, Identifiable, Codable {
  case frontFace = 0  // Ön yüz
  case rightProfile = 1  // Sağ profil
  case leftProfile = 2  // Sol profil
  case vertex = 3  // Tepe
  case donorArea = 4  // Arka donör bölgesi

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .frontFace: return "Ön Yüz"
    case .rightProfile: return "Sağ Profil"
    case .leftProfile: return "Sol Profil"
    case .vertex: return "Tepe"
    case .donorArea: return "Arka Donör"
    }
  }

  var instructions: String {
    switch self {
    case .frontFace:
      return "Yüzünüzü kameraya bakın"
    case .rightProfile:
      return "Başınızı 45° sağa çevirin"
    case .leftProfile:
      return "Başınızı 45° sola çevirin"
    case .vertex:
      return "Telefonu tepe bölgesine tutun"
    case .donorArea:
      return "Telefonu ense bölgesine tutun"
    }
  }

  // Hedef pitch açısı (derece)
  // Camera-relative angles: measured relative to device, not gravity
  // Positive pitch = looking up, Negative pitch = looking down
  var targetPitch: Double {
    switch self {
    case .frontFace, .rightProfile, .leftProfile: return 0.0  // Face level with camera
    case .vertex: return 90.0  // Phone above head, perpendicular to ground
    case .donorArea: return 165.0  // Phone at back of head, nearly upside down (180° - slight angle)
    }
  }

  // Pitch toleransı (derece)
  var pitchTolerance: Double {
    switch self {
    case .frontFace, .rightProfile, .leftProfile: return 15.0  // Reasonably strict for face views
    case .vertex: return 20.0  // Moderate tolerance for top view
    case .donorArea: return 40.0  // Very flexible for back/nape view - accepts both upright (127°) and upside-down (165°) positions
    }
  }
  
  // Roll (yan dönüş) için hedef açı - sadece donorArea için gerekli
  var targetRoll: Double? {
    switch self {
    case .frontFace, .rightProfile, .leftProfile, .vertex: 
      return nil  // Roll önemli değil
    case .donorArea: 
      return 180.0  // Telefon tamamen ters (±180°)
    }
  }
  
  // Roll toleransı
  var rollTolerance: Double {
    switch self {
    case .donorArea: return 40.0  // Geniş tolerans - ±180° etrafında
    default: return 180.0  // Diğerleri için roll önemli değil
    }
  }

  // Hedef yaw açısı (derece) - yüz rotasyonu için
  // Camera-relative: positive = turned right, negative = turned left
  var targetYaw: Double? {
    switch self {
    case .frontFace: return 0.0  // Face straight at camera
    case .rightProfile: return 45.0  // Turn right 45°
    case .leftProfile: return -45.0  // Turn left 45°
    case .vertex, .donorArea: return nil  // Don't validate yaw for top/back views
    }
  }

  // Yaw toleransı (derece)
  var yawTolerance: Double {
    switch self {
    case .frontFace: return 15.0  // Front view strict - face must be centered
    case .rightProfile, .leftProfile: return 15.0  // Profile views need precision
    default: return 45.0  // Other views more flexible
    }
  }

  // SF Symbol ikonu
  var symbolName: String {
    switch self {
    case .frontFace: return "person.crop.circle"
    case .rightProfile: return "arrow.turn.up.right"
    case .leftProfile: return "arrow.turn.up.left"
    case .vertex: return "arrow.up.circle"
    case .donorArea: return "arrow.backward.circle"
    }
  }

  // Sıradaki açı
  var next: CaptureAngle? {
    guard rawValue < CaptureAngle.allCases.count - 1 else { return nil }
    return CaptureAngle(rawValue: rawValue + 1)
  }
}
