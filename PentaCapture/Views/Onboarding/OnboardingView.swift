//
//  OnboardingView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Onboarding view explaining the capture process
struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    private let pages = [
        OnboardingPage(
            icon: "camera.fill",
            title: "5 Açıdan Fotoğraf",
            description: "Saç analizi için 5 farklı açıdan fotoğraf çekeceğiz. Uygulama sizi adım adım yönlendirecek.",
            color: .blue
        ),
        OnboardingPage(
            icon: "hand.raised.fill",
            title: "Otomatik Çekim",
            description: "Telefonu doğru pozisyona getirdiğinizde fotoğraf otomatik olarak çekilir. Elle de çekebilirsiniz.",
            color: .green
        ),
        OnboardingPage(
            icon: "figure.stand",
            title: "Pozisyon Kılavuzu",
            description: "Ekrandaki görsel kılavuzlar ve sesli geri bildirimler doğru pozisyonu bulmanıza yardımcı olacak.",
            color: .orange
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "Kaliteli Görüntü",
            description: "Net ve tutarlı fotoğraflar için aydınlık bir ortamda çekim yapın ve telefonu sabit tutun.",
            color: .purple
        )
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
                                            Color.white.opacity(0.05)
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
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Action button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Devam" : "Başlayalım")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
    }
}

/// Single onboarding page
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

/// View for a single onboarding page
struct OnboardingPageView: View {
    let page: OnboardingPage
    
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
        }
    }
}

/// Compact onboarding with all angles shown
struct CompactOnboardingView: View {
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("5 Açıdan Çekim")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Aşağıdaki açılardan fotoğraf çekeceğiz")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 40)
                    
                    // Angles list
                    VStack(spacing: 16) {
                        ForEach(CaptureAngle.allCases) { angle in
                            AngleCard(angle: angle)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tips
                    TipsSection()
                        .padding()
                    
                    // Start button
                    Button(action: onComplete) {
                        Text("Başlat")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
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

// MARK: - Preview
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView(onComplete: {})
            
            CompactOnboardingView(onComplete: {})
        }
    }
}
#endif

