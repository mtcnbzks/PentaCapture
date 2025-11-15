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
  @State private var showingReview = false
  @State private var shouldStartCaptureAfterOnboarding = false
  @State private var showingContinueAlert = false
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appOpenCount") private var appOpenCount = 0
  @AppStorage("debugMode") private var debugMode = false

  @StateObject private var sessionPersistenceService = SessionPersistenceService()
  @StateObject private var storageService = StorageService()

  var body: some View {
    NavigationStack {
      ZStack {
        // Minimal gradient background
        LinearGradient(
          colors: [
            Color(red: 0.1, green: 0.1, blue: 0.15),
            Color(red: 0.15, green: 0.1, blue: 0.2),
            Color(red: 0.2, green: 0.1, blue: 0.25)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        // ScrollView to handle dynamic content
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            // Settings button - minimal
            HStack {
              Spacer()
              Button(action: {
                showingSettings = true
              }) {
                Image(systemName: "gearshape.fill")
                  .font(.system(size: 20))
                  .foregroundColor(.white.opacity(0.8))
                  .padding(10)
                  .background(
                    RoundedRectangle(cornerRadius: 10)
                      .fill(Color.white.opacity(0.1))
                  )
              }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)

            // App icon - minimal
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120, height: 120)

              Image(systemName: "camera.metering.multispot")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white)
            }
            .padding(.bottom, 24)

            // App title - minimal
            VStack(spacing: 6) {
              Text("PentaCapture")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

              Text("5 Açıdan Profesyonel Saç Fotoğrafı")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            // Continue session card (if available)
            if let metadata = sessionPersistenceService.savedSessionMetadata {
              ContinueSessionCard(
                metadata: metadata,
                onContinue: {
                  // If session is complete (5/5 photos), go directly to review
                  if metadata.capturedCount == metadata.totalCount {
                    showingReview = true
                  } else {
                    showingCapture = true
                  }
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
              .padding(.horizontal, 24)
              .padding(.bottom, 16)
              .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
              // Features info when no session
              VStack(spacing: 12) {
                FeatureRow(icon: "camera.metering.multispot", text: "5 farklı açıdan fotoğraf")
                FeatureRow(icon: "hand.raised", text: "Otomatik çekim sistemi")
                FeatureRow(icon: "bolt.fill", text: "Hızlı ve kolay")
              }
              .padding(.horizontal, 24)
              .padding(.vertical, 16)
              .background(
                RoundedRectangle(cornerRadius: 14)
                  .fill(Color.white.opacity(0.05))
              )
              .padding(.horizontal, 24)
              .padding(.bottom, 16)
            }

            // Action buttons - minimal
            VStack(spacing: 12) {
              // Start capture button - primary
              Button(action: {
                if sessionPersistenceService.savedSessionMetadata != nil {
                  showingContinueAlert = true
                } else if !hasCompletedOnboarding {
                  shouldStartCaptureAfterOnboarding = true
                  showingOnboarding = true
                } else {
                  showingCapture = true
                }
              }) {
                HStack(spacing: 8) {
                  Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                  Text("Fotoğraf Çekmeye Başla")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                  RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                )
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
              }

              // Tutorial button - secondary
              Button(action: {
                shouldStartCaptureAfterOnboarding = false
                showingOnboarding = true
              }) {
                HStack(spacing: 8) {
                  Image(systemName: hasCompletedOnboarding ? "info.circle" : "play.circle")
                    .font(.system(size: 16, weight: .medium))
                  Text(hasCompletedOnboarding ? "Nasıl Kullanılır?" : "Rehberi Göster")
                    .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                  RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.white.opacity(0.9))
              }
            }
            .padding(.horizontal, 24)
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
        .presentationDetents([.height(550), .large])
        .presentationDragIndicator(.visible)
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
      .sheet(isPresented: $showingReview) {
        if let session = sessionPersistenceService.loadSession() {
          ReviewView(
            session: session,
            storageService: storageService,
            onRetake: { angle in
              showingReview = false
              // Clear specific angle and restart capture
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingCapture = true
              }
            },
            onComplete: {
              // Just close review - don't clear session
              // User can manually clear from "Yeni Başla" button or settings
              showingReview = false
            },
            onSaveToGallery: {}
          )
        }
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
    .preferredColorScheme(.dark)
  }
}

// MARK: - Continue Session Card - minimal design
struct ContinueSessionCard: View {
  let metadata: SessionPersistenceService.SessionMetadata
  let onContinue: () -> Void
  let onStartNew: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Header
      HStack {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.white.opacity(0.8))

        Text("Yarım Kalan Çekim")
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(.white)

        Spacer()
      }

      // Info
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("\(metadata.capturedCount)/\(metadata.totalCount) fotoğraf")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))

          Spacer()

          Text(SessionPersistenceService.formatTimeSince(metadata.lastSavedTime))
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.5))
        }

        // Progress bar
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
              .fill(Color.white.opacity(0.15))
              .frame(height: 5)

            RoundedRectangle(cornerRadius: 3)
              .fill(Color.white)
              .frame(
                width: geometry.size.width * metadata.progress,
                height: 5
              )
          }
        }
        .frame(height: 5)

        // Sadece session tamamlanmamışsa "Sıradaki" göster
        if metadata.capturedCount < metadata.totalCount {
          Text("Sıradaki: \(metadata.currentAngle.title)")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }
      }

      // Actions
      HStack(spacing: 8) {
        Button(action: onContinue) {
          HStack(spacing: 6) {
            Image(systemName: "play.fill")
              .font(.system(size: 13))
            Text("Devam Et")
              .font(.system(size: 15, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white)
          )
          .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
        }

        Button(action: onStartNew) {
          HStack(spacing: 6) {
            Image(systemName: "arrow.counterclockwise")
              .font(.system(size: 13))
            Text("Yeni Başla")
              .font(.system(size: 14, weight: .medium))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white.opacity(0.15))
          )
          .foregroundColor(.white.opacity(0.9))
        }
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.white.opacity(0.08))
    )
  }
}

// MARK: - Settings View - minimal design
struct SettingsView: View {
  @Binding var debugMode: Bool
  @ObservedObject var sessionPersistence: SessionPersistenceService
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        // Background to match main screen
        Color(red: 0.05, green: 0.05, blue: 0.08)
          .ignoresSafeArea()

        Form {
          Section {
            Toggle("Debug Overlay", isOn: $debugMode)
              .tint(.white)
          } header: {
            Text("Geliştirici Ayarları")
          } footer: {
            Text("ARKit tracking durumu ve yüz pozisyonu değerlerini gösterir.")
          }
          .listRowBackground(Color.white.opacity(0.08))

          // Session Auto-Save Debug Info
          Section {
            VStack(alignment: .leading, spacing: 8) {
              if let metadata = sessionPersistence.savedSessionMetadata {
                Label("Kaydedilmiş Session Var!", systemImage: "checkmark.circle.fill")
                  .foregroundColor(.green)
                  .font(.system(size: 15, weight: .semibold))

                Divider()
                  .background(Color.white.opacity(0.1))

                HStack {
                  Text("Session ID:")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                  Spacer()
                  Text(metadata.sessionId.uuidString.prefix(8) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                }

                HStack {
                  Text("Başlangıç:")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                  Spacer()
                  Text(formatDate(metadata.startTime))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }

                HStack {
                  Text("Son Kayıt:")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                  Spacer()
                  Text(SessionPersistenceService.formatTimeSince(metadata.lastSavedTime))
                    .font(.caption)
                    .foregroundColor(.orange)
                }

                HStack {
                  Text("İlerleme:")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                  Spacer()
                  Text("\(metadata.capturedCount)/\(metadata.totalCount) fotoğraf")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                }

                HStack {
                  Text("Sıradaki Açı:")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                  Spacer()
                  Text(metadata.currentAngle.title)
                    .font(.caption)
                    .foregroundColor(.white)
                }

                Divider()
                  .background(Color.white.opacity(0.1))

                Button(role: .destructive) {
                  sessionPersistence.clearSession()
                } label: {
                  Label("Kaydedilmiş Session'ı Temizle", systemImage: "trash")
                }
              } else {
                Label("Kaydedilmiş Session Yok", systemImage: "info.circle")
                  .foregroundColor(.white.opacity(0.6))

                Text("Bir çekim başlatıp yarıda bıraktığında burada görünecek.")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.5))
                  .padding(.top, 4)
              }
            }
          } header: {
            Text("Session Auto-Save")
          } footer: {
            Text("Yarım kalan çekimler otomatik olarak kaydedilir ve uygulama açıldığında devam edebilirsin.")
          }
          .listRowBackground(Color.white.opacity(0.08))

          Section {
            HStack {
              Text("Versiyon")
              Spacer()
              Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                .foregroundColor(.white.opacity(0.6))
            }

            HStack {
              Text("Kayıt Konumu")
              Spacer()
              Text("Application Support")
                .foregroundColor(.white.opacity(0.6))
                .font(.caption)
            }
          } header: {
            Text("Hakkında")
          }
          .listRowBackground(Color.white.opacity(0.08))
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle("Ayarlar")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.08), for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Tamam") {
            dismiss()
          }
          .foregroundColor(.white)
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

// MARK: - Feature Row
struct FeatureRow: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
        .frame(width: 24)

      Text(text)
        .font(.system(size: 15, weight: .regular))
        .foregroundColor(.white.opacity(0.7))

      Spacer()
    }
  }
}
