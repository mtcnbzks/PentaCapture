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

  private let pages = [
    OnboardingPage(
      icon: "camera.fill",
      title: "5 Açıdan Fotoğraf",
      description:
        "Saç analizi için 5 farklı açıdan fotoğraf çekeceğiz. Uygulama sizi adım adım yönlendirecek.",
      color: .blue,
      needsCameraPermission: true
    ),
    OnboardingPage(
      icon: "hand.raised.fill",
      title: "Otomatik Çekim",
      description:
        "Telefonu doğru pozisyona getirdiğinizde fotoğraf otomatik olarak çekilir. Elle de çekebilirsiniz.",
      color: .green,
      needsCameraPermission: false
    ),
    OnboardingPage(
      icon: "figure.stand",
      title: "Pozisyon Kılavuzu",
      description:
        "Ekrandaki görsel kılavuzlar ve sesli geri bildirimler doğru pozisyonu bulmanıza yardımcı olacak.",
      color: .orange,
      needsCameraPermission: false
    ),
    OnboardingPage(
      icon: "checkmark.seal.fill",
      title: "Kaliteli Görüntü",
      description:
        "Net ve tutarlı fotoğraflar için aydınlık bir ortamda çekim yapın ve telefonu sabit tutun.",
      color: .purple,
      needsCameraPermission: false,
      needsPhotoLibraryPermission: true
    ),
  ]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black, Color(white: 0.15)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 40) {
        // Skip button
        HStack {
          Spacer()
          Button("Geç") {
            onComplete()
          }
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.white.opacity(0.9))
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(
            ZStack {
              // Liquid glass effect
              RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))

              RoundedRectangle(cornerRadius: 20)
                .fill(
                  LinearGradient(
                    colors: [
                      Color.white.opacity(0.15),
                      Color.white.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )

              RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
          )
          .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
          .padding(.trailing, 20)
          .padding(.top, 10)
        }

        // Page view
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

        // Navigation buttons
        HStack(spacing: 16) {
          // Back button (hidden on first page)
          if currentPage > 0 {
            Button(action: {
              withAnimation {
                currentPage -= 1
              }
            }) {
              HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                  .font(.system(size: 16, weight: .semibold))
                Text("Geri")
                  .font(.headline)
              }
              .foregroundColor(.white.opacity(0.8))
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.white.opacity(0.15))
              .cornerRadius(16)
            }
          }

          // Next/Start button
          Button(action: {
            if currentPage < pages.count - 1 {
              withAnimation {
                currentPage += 1
              }
            } else {
              onComplete()
            }
          }) {
            HStack(spacing: 8) {
              Text(currentPage < pages.count - 1 ? "Devam" : "Başlayalım")
                .font(.headline)
              if currentPage < pages.count - 1 {
                Image(systemName: "chevron.right")
                  .font(.system(size: 16, weight: .semibold))
              }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(16)
          }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 30)
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
    VStack(spacing: 30) {
      // Icon
      ZStack {
        Circle()
          .fill(page.color.opacity(0.2))
          .frame(width: 200, height: 200)

        Circle()
          .fill(page.color.opacity(0.4))
          .frame(width: 160, height: 160)

        Image(systemName: page.icon)
          .font(.system(size: 80))
          .foregroundColor(page.color)
      }

      // Title
      Text(page.title)
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)

      // Description
      Text(page.description)
        .font(.body)
        .foregroundColor(.white.opacity(0.8))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      // Permission buttons
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
        .padding(.horizontal, 40)
        .padding(.top, 20)
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
        .padding(.horizontal, 40)
        .padding(.top, 20)
      }
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

/// Permission button component
struct PermissionButton: View {
  let title: String
  let icon: String
  let isGranted: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundColor(isGranted ? .green : .white)

        Text(title)
          .font(.headline)
          .foregroundColor(isGranted ? .green : .white)

        Spacer()

        if isGranted {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.green)
        } else {
          Image(systemName: "arrow.right.circle")
            .font(.system(size: 24))
            .foregroundColor(.white.opacity(0.6))
        }
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isGranted ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isGranted ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
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
