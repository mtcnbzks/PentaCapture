//
//  OnboardingView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import AVFoundation
import Photos
import SwiftUI

/// Onboarding view explaining the capture process
struct OnboardingView: View {
  @State private var currentPage = 0
  @State private var cameraPermissionGranted = false
  @State private var photoLibraryPermissionGranted = false
  let onComplete: () -> Void
  let onSkip: (() -> Void)?

  private let pages = [
    OnboardingPage(
      icon: "camera.fill",
      title: "5 Farklı Açı",
      description:
        "Başınızın her tarafını görmek için 5 açıdan fotoğraf çekeceğiz.",
      color: .blue,
      needsCameraPermission: true
    ),
    OnboardingPage(
      icon: "hand.raised.fill",
      title: "Otomatik Çekim",
      description:
        "Doğru pozisyona geldiğinizde fotoğraf kendiliğinden çekilir.",
      color: .green,
      needsCameraPermission: false
    ),
    OnboardingPage(
      icon: "figure.stand",
      title: "Kolay Kılavuz",
      description:
        "Ekrandaki görseller ve sesli yönlendirme size yardımcı olur.",
      color: .orange,
      needsCameraPermission: false
    ),
    OnboardingPage(
      icon: "checkmark.seal.fill",
      title: "Net Fotoğraf",
      description:
        "Aydınlık bir yerde durun ve telefonu sabit tutun.",
      color: .purple,
      needsCameraPermission: false,
      needsPhotoLibraryPermission: false  // Galeri izni artık isteğe bağlı - galeriye kaydet butonuna basıldığında istenecek
    ),
  ]

  var body: some View {
    ZStack {
      // Minimal gradient background
      LinearGradient(
        colors: [Color.black, Color(white: 0.1)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        // Skip button - minimal
        HStack {
          Spacer()
          Button("Geç") {
            if let onSkip = onSkip {
              onSkip()
            } else {
              onComplete()
            }
          }
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white.opacity(0.7))
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white.opacity(0.1))
          )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)

        // Page view with fixed height to prevent scrolling issues
        TabView(selection: $currentPage) {
          ForEach(0..<pages.count, id: \.self) { index in
            OnboardingPageView(
              page: pages[index],
              cameraPermissionGranted: $cameraPermissionGranted,
              photoLibraryPermissionGranted: $photoLibraryPermissionGranted
            )
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))

        // Navigation buttons - minimal
        HStack(spacing: 12) {
          // Back button
          if currentPage > 0 {
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                currentPage -= 1
              }
            }) {
              HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                  .font(.system(size: 14, weight: .semibold))
                Text("Geri")
                  .font(.system(size: 16, weight: .medium))
              }
              .foregroundColor(.white.opacity(0.8))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(
                RoundedRectangle(cornerRadius: 14)
                  .fill(Color.white.opacity(0.1))
              )
            }
          }

          // Next/Start button
          Button(action: {
            if currentPage < pages.count - 1 {
              withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
              }
            } else {
              onComplete()
            }
          }) {
            HStack(spacing: 6) {
              Text(currentPage < pages.count - 1 ? "Devam" : "Başlayalım")
                .font(.system(size: 16, weight: .semibold))
              if currentPage < pages.count - 1 {
                Image(systemName: "chevron.right")
                  .font(.system(size: 14, weight: .semibold))
              }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              RoundedRectangle(cornerRadius: 14)
                .fill(
                  LinearGradient(
                    colors: isNextButtonEnabled ? [Color.blue, Color.blue.opacity(0.8)] : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            )
          }
          .disabled(!isNextButtonEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
    }
    .onAppear {
      checkExistingPermissions()
    }
  }

  private func checkExistingPermissions() {
    // Check camera permission
    let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    cameraPermissionGranted = (cameraStatus == .authorized)

    // Check photo library permission
    let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    photoLibraryPermissionGranted = (photoStatus == .authorized || photoStatus == .limited)
  }
  
  // Check if next/start button should be enabled
  private var isNextButtonEnabled: Bool {
    let currentPageData = pages[currentPage]
    
    // If current page needs camera permission, require it
    if currentPageData.needsCameraPermission && !cameraPermissionGranted {
      return false
    }
    
    // Photo library permission is optional - don't block user
    // They can grant it later when saving to gallery
    
    return true
  }
}

/// Single onboarding page
struct OnboardingPage {
  let icon: String
  let title: String
  let description: String
  let color: Color
  var needsCameraPermission: Bool = false
  var needsPhotoLibraryPermission: Bool = false
}

/// View for a single onboarding page
struct OnboardingPageView: View {
  let page: OnboardingPage
  @Binding var cameraPermissionGranted: Bool
  @Binding var photoLibraryPermissionGranted: Bool

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: 40)

      // Icon - minimal
      ZStack {
        Circle()
          .fill(page.color.opacity(0.15))
          .frame(width: 90, height: 90)

        Image(systemName: page.icon)
          .font(.system(size: 40, weight: .light))
          .foregroundColor(page.color)
      }
      .padding(.bottom, 28)

      // Title
      Text(page.title)
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.bottom, 12)

      // Description
      Text(page.description)
        .font(.system(size: 16, weight: .regular))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .padding(.horizontal, 32)
        .fixedSize(horizontal: false, vertical: true)

      // Permission buttons area - fixed height to maintain consistency
      VStack(spacing: 10) {
        if page.needsCameraPermission {
          PermissionButton(
            title: "Kamera Erişimi",
            icon: "camera.fill",
            isGranted: cameraPermissionGranted,
            action: {
              requestCameraPermission { granted in
                cameraPermissionGranted = granted
              }
            }
          )
        }

        if page.needsPhotoLibraryPermission {
          PermissionButton(
            title: "Galeri Erişimi",
            icon: "photo.fill",
            isGranted: photoLibraryPermissionGranted,
            action: {
              requestPhotoLibraryPermission { granted in
                photoLibraryPermissionGranted = granted
              }
            }
          )
        }
      }
      .frame(height: 100) // Fixed height for permission area
      .padding(.horizontal, 32)
      .padding(.top, 24)

      Spacer()
    }
  }

  private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        completion(granted)
      }
    }
  }

  private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      DispatchQueue.main.async {
        completion(status == .authorized || status == .limited)
      }
    }
  }
}

/// Permission button component - minimal design
struct PermissionButton: View {
  let title: String
  let icon: String
  let isGranted: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(isGranted ? .green : .white.opacity(0.9))
          .frame(width: 24)

        Text(title)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(isGranted ? .green : .white.opacity(0.9))

        Spacer()

        if isGranted {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(.green)
        } else {
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.4))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isGranted ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isGranted ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
      )
    }
    .disabled(isGranted)
  }
}

/// Card showing single angle info
struct AngleCard: View {
  let angle: CaptureAngle

  var body: some View {
    HStack(spacing: 16) {
      // Number badge
      ZStack {
        Circle()
          .fill(Color.blue)
          .frame(width: 40, height: 40)

        Text("\(angle.rawValue + 1)")
          .font(.headline)
          .fontWeight(.bold)
          .foregroundColor(.white)
      }

      // Icon
      Image(systemName: angle.symbolName)
        .font(.system(size: 30))
        .foregroundColor(.white)
        .frame(width: 50)

      // Info
      VStack(alignment: .leading, spacing: 4) {
        Text(angle.title)
          .font(.headline)
          .foregroundColor(.white)

        Text(angle.instructions)
          .font(.caption)
          .foregroundColor(.white.opacity(0.7))
      }

      Spacer()
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.1))
    )
  }
}

/// Tips section
struct TipsSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("İpuçları")
        .font(.title3)
        .fontWeight(.bold)
        .foregroundColor(.white)

      TipRow(icon: "lightbulb.fill", text: "Aydınlık bir ortamda çekim yapın")
      TipRow(icon: "hand.raised.fill", text: "Telefonu sabit tutun")
      TipRow(icon: "speaker.wave.3.fill", text: "Sesli geri bildirimleri açık tutun")
      TipRow(icon: "checkmark.circle.fill", text: "Ekrandaki kılavuzları takip edin")
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.blue.opacity(0.2))
    )
  }
}

/// Single tip row
struct TipRow: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundColor(.blue)
        .frame(width: 30)

      Text(text)
        .font(.subheadline)
        .foregroundColor(.white.opacity(0.9))

      Spacer()
    }
  }
}
