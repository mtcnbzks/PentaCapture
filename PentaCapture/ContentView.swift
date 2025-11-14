//
//  ContentView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

struct ContentView: View {
  @State private var showingOnboarding = false
  @State private var showingCapture = false
  @State private var showingSettings = false
  @State private var shouldStartCaptureAfterOnboarding = false
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appOpenCount") private var appOpenCount = 0
  @AppStorage("debugMode") private var debugMode = false

  var body: some View {
    NavigationStack {
      ZStack {
        // Modern gradient background with multiple colors
        LinearGradient(
          colors: [
            Color(red: 0.2, green: 0.4, blue: 0.9),
            Color(red: 0.4, green: 0.2, blue: 0.8),
            Color(red: 0.6, green: 0.1, blue: 0.7)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        // Animated background circles for depth
        GeometryReader { geometry in
          ZStack {
            Circle()
              .fill(Color.white.opacity(0.05))
              .frame(width: 300, height: 300)
              .offset(x: -100, y: -100)
            
            Circle()
              .fill(Color.white.opacity(0.03))
              .frame(width: 200, height: 200)
              .offset(x: geometry.size.width - 100, y: geometry.size.height - 150)
          }
        }

        VStack(spacing: 40) {
          // Settings button with glassmorphism
          HStack {
            Spacer()
            Button(action: {
              showingSettings = true
            }) {
              Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .padding(12)
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                    )
                )
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)

          Spacer()

          // Modern app icon with glow effect
          ZStack {
            // Outer glow
            Circle()
              .fill(
                RadialGradient(
                  colors: [Color.white.opacity(0.3), Color.clear],
                  center: .center,
                  startRadius: 60,
                  endRadius: 100
                )
              )
              .frame(width: 200, height: 200)
            
            // Glassmorphic background
            Circle()
              .fill(Color.white.opacity(0.15))
              .background(
                Circle()
                  .fill(.ultraThinMaterial)
              )
              .frame(width: 140, height: 140)

            // Icon
            Image(systemName: "camera.metering.multispot")
              .font(.system(size: 60, weight: .light))
              .foregroundColor(.white)
              .shadow(color: .white.opacity(0.3), radius: 10)
          }

          // App title with better typography
          VStack(spacing: 8) {
            Text("PentaCapture")
              .font(.system(size: 44, weight: .bold, design: .rounded))
              .foregroundStyle(
                LinearGradient(
                  colors: [.white, .white.opacity(0.9)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("5 Açıdan Profesyonel Saç Fotoğrafı")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white.opacity(0.85))
              .multilineTextAlignment(.center)
          }

          Spacer()

          // Modern action buttons with glassmorphism
          VStack(spacing: 14) {
            // Start capture button - primary
            Button(action: {
              if !hasCompletedOnboarding {
                shouldStartCaptureAfterOnboarding = true
                showingOnboarding = true
              } else {
                showingCapture = true
              }
            }) {
              HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                  .font(.system(size: 18, weight: .semibold))
                Text("Fotoğraf Çekmeye Başla")
                  .font(.system(size: 17, weight: .semibold))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 18)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white)
                  .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
              )
              .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.9))
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingCapture)

            // Tutorial button - secondary with glassmorphism
            Button(action: {
              shouldStartCaptureAfterOnboarding = false
              showingOnboarding = true
            }) {
              HStack(spacing: 10) {
                Image(systemName: hasCompletedOnboarding ? "info.circle.fill" : "play.circle.fill")
                  .font(.system(size: 18, weight: .medium))
                Text(hasCompletedOnboarding ? "Nasıl Kullanılır?" : "Rehberi Göster")
                  .font(.system(size: 16, weight: .medium))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.15))
                  .background(
                    RoundedRectangle(cornerRadius: 16)
                      .fill(.ultraThinMaterial)
                  )
              )
              .foregroundColor(.white)
            }
          }
          .padding(.horizontal, 28)
          .padding(.bottom, 50)
        }
      }
      .sheet(
        isPresented: $showingOnboarding,
        onDismiss: {
          // Sheet tamamen kapandıktan sonra, eğer onboarding tamamlandıysa çekime geç
          if shouldStartCaptureAfterOnboarding {
            shouldStartCaptureAfterOnboarding = false
            // Küçük bir delay ile daha smooth geçiş
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              showingCapture = true
            }
          }
        }
      ) {
        OnboardingView {
          // Onboarding tamamlandı
          hasCompletedOnboarding = true
          shouldStartCaptureAfterOnboarding = true
          showingOnboarding = false
        }
      }
      .fullScreenCover(isPresented: $showingCapture) {
        CaptureFlowView(viewModel: CaptureViewModel())
      }
      .sheet(isPresented: $showingSettings) {
        SettingsView(debugMode: $debugMode)
      }
    }
    .onAppear {
      // Track app opens
      appOpenCount += 1

      // Smart onboarding logic
      if !hasCompletedOnboarding && appOpenCount <= 1 {
        // First time user - show onboarding automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          showingOnboarding = true
        }
      }
      // Returning users (hasCompletedOnboarding == true) don't see onboarding
      // They can manually open it via "Nasıl Kullanılır?" button
    }
  }
}

// MARK: - Settings View
struct SettingsView: View {
  @Binding var debugMode: Bool
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Debug Overlay", isOn: $debugMode)
        } header: {
          Text("Geliştirici Ayarları")
        } footer: {
          Text("ARKit tracking durumu ve yüz pozisyonu değerlerini gösterir.")
        }
        
        Section {
          HStack {
            Text("Versiyon")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
              .foregroundColor(.secondary)
          }
        } header: {
          Text("Hakkında")
        }
      }
      .navigationTitle("Ayarlar")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Tamam") {
            dismiss()
          }
        }
      }
    }
  }
}
