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
  @State private var showingContinueAlert = false
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appOpenCount") private var appOpenCount = 0
  @AppStorage("debugMode") private var debugMode = false
  
  @StateObject private var sessionPersistenceService = SessionPersistenceService()

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

        // ScrollView to handle dynamic content (continue session card)
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
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
            .padding(.bottom, 40)

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
            .padding(.vertical, 20)

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
            .padding(.bottom, 30)
            
            // Continue session card (if available)
            if let metadata = sessionPersistenceService.savedSessionMetadata {
              ContinueSessionCard(
                metadata: metadata,
                onContinue: {
                  showingCapture = true
                },
              onStartNew: {
                sessionPersistenceService.clearSession()
                if !hasCompletedOnboarding {
                  shouldStartCaptureAfterOnboarding = true
                  showingOnboarding = true
                } else {
                  showingCapture = true
                }
              }
              )
              .padding(.horizontal, 28)
              .padding(.bottom, 16)
              .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Modern action buttons with glassmorphism
            VStack(spacing: 14) {
              // Start capture button - primary
              Button(action: {
                // If there's a saved session, ask user what to do
                if sessionPersistenceService.savedSessionMetadata != nil {
                  showingContinueAlert = true
                } else if !hasCompletedOnboarding {
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
        OnboardingView(
          onComplete: {
            // Onboarding tamamlandı - "Başlayalım" butonuna basıldı
            hasCompletedOnboarding = true
            shouldStartCaptureAfterOnboarding = true
            showingOnboarding = false
          },
          onSkip: {
            // Onboarding atlandı - "Geç" butonuna basıldı
            hasCompletedOnboarding = true
            shouldStartCaptureAfterOnboarding = false  // Ana ekrana dön
            showingOnboarding = false
          }
        )
      }
      .fullScreenCover(isPresented: $showingCapture) {
        // Restore session if there's saved metadata
        let shouldRestore = sessionPersistenceService.savedSessionMetadata != nil
        CaptureFlowView(
          viewModel: CaptureViewModel(
            sessionPersistenceService: sessionPersistenceService,
            restoreSession: shouldRestore
          )
        )
      }
      .sheet(isPresented: $showingSettings) {
        SettingsView(
          debugMode: $debugMode,
          sessionPersistence: sessionPersistenceService
        )
      }
    }
    .onAppear {
      // Track app opens
      appOpenCount += 1
      
      // Log saved session info
      if let metadata = sessionPersistenceService.savedSessionMetadata {
        print("📱 Found saved session: \(metadata.capturedCount)/\(metadata.totalCount) photos, last saved \(SessionPersistenceService.formatTimeSince(metadata.lastSavedTime))")
      }

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
    .alert("Devam Etmek İster misin?", isPresented: $showingContinueAlert) {
      Button("Kaldığım Yerden Devam Et") {
        showingCapture = true
      }
      Button("Yeni Başla") {
        sessionPersistenceService.clearSession()
        if !hasCompletedOnboarding {
          shouldStartCaptureAfterOnboarding = true
          showingOnboarding = true
        } else {
          showingCapture = true
        }
      }
      Button("İptal", role: .cancel) {}
    } message: {
      if let metadata = sessionPersistenceService.savedSessionMetadata {
        Text("Yarım kalan çekimin var (\(metadata.capturedCount)/\(metadata.totalCount) fotoğraf). Kaldığın yerden devam etmek ister misin?")
      }
    }
  }
}

// MARK: - Continue Session Card
struct ContinueSessionCard: View {
  let metadata: SessionPersistenceService.SessionMetadata
  let onContinue: () -> Void
  let onStartNew: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.blue)
        
        Text("Yarım Kalan Çekim")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.white)
        
        Spacer()
      }
      
      // Info
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("\(metadata.capturedCount)/\(metadata.totalCount) fotoğraf")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
          
          Spacer()
          
          Text(SessionPersistenceService.formatTimeSince(metadata.lastSavedTime))
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.7))
        }
        
        // Progress bar
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.white.opacity(0.2))
              .frame(height: 6)
            
            // Progress
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.blue)
              .frame(
                width: geometry.size.width * metadata.progress,
                height: 6
              )
          }
        }
        .frame(height: 6)
        
        Text("Sıradaki: \(metadata.currentAngle.title)")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white.opacity(0.8))
      }
      
      // Actions
      HStack(spacing: 10) {
        Button(action: onContinue) {
          HStack {
            Image(systemName: "play.fill")
              .font(.system(size: 14))
            Text("Devam Et")
              .font(.system(size: 15, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.blue)
          )
          .foregroundColor(.white)
        }
        
        Button(action: onStartNew) {
          HStack {
            Image(systemName: "arrow.counterclockwise")
              .font(.system(size: 14))
            Text("Yeni Başla")
              .font(.system(size: 15, weight: .medium))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white.opacity(0.2))
          )
          .foregroundColor(.white)
        }
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.15))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
        )
    )
  }
}

// MARK: - Settings View
struct SettingsView: View {
  @Binding var debugMode: Bool
  @ObservedObject var sessionPersistence: SessionPersistenceService
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
        
        // Session Auto-Save Debug Info
        Section {
          VStack(alignment: .leading, spacing: 8) {
            if let metadata = sessionPersistence.savedSessionMetadata {
              Label("Kaydedilmiş Session Var!", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.headline)
              
              Divider()
              
              HStack {
                Text("Session ID:")
                  .foregroundColor(.secondary)
                Spacer()
                Text(metadata.sessionId.uuidString.prefix(8) + "...")
                  .font(.system(.caption, design: .monospaced))
              }
              
              HStack {
                Text("Başlangıç:")
                  .foregroundColor(.secondary)
                Spacer()
                Text(formatDate(metadata.startTime))
                  .font(.caption)
              }
              
              HStack {
                Text("Son Kayıt:")
                  .foregroundColor(.secondary)
                Spacer()
                Text(SessionPersistenceService.formatTimeSince(metadata.lastSavedTime))
                  .font(.caption)
                  .foregroundColor(.orange)
              }
              
              HStack {
                Text("İlerleme:")
                  .foregroundColor(.secondary)
                Spacer()
                Text("\(metadata.capturedCount)/\(metadata.totalCount) fotoğraf")
                  .font(.caption)
                  .bold()
              }
              
              HStack {
                Text("Sıradaki Açı:")
                  .foregroundColor(.secondary)
                Spacer()
                Text(metadata.currentAngle.title)
                  .font(.caption)
                  .foregroundColor(.blue)
              }
              
              Divider()
              
              Button(role: .destructive) {
                sessionPersistence.clearSession()
              } label: {
                Label("Kaydedilmiş Session'ı Temizle", systemImage: "trash")
              }
            } else {
              Label("Kaydedilmiş Session Yok", systemImage: "info.circle")
                .foregroundColor(.secondary)
              
              Text("Bir çekim başlatıp yarıda bıraktığında burada görünecek.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
          }
        } header: {
          Text("Session Auto-Save")
        } footer: {
          Text("Yarım kalan çekimler otomatik olarak kaydedilir ve uygulama açıldığında devam edebilirsin.")
        }
        
        Section {
          HStack {
            Text("Versiyon")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Kayıt Konumu")
            Spacer()
            Text("Application Support")
              .foregroundColor(.secondary)
              .font(.caption)
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
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.locale = Locale(identifier: "tr_TR")
    return formatter.string(from: date)
  }
}
