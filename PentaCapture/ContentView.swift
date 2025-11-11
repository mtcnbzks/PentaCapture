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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appOpenCount") private var appOpenCount = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App icon/logo
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 150, height: 150)
                        
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }
                    
                    // App title
                    VStack(spacing: 12) {
                        Text("PentaCapture")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("5 Açıdan Profesyonel Saç Fotoğrafı")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Start capture button
                        Button(action: {
                            if !hasCompletedOnboarding {
                                showingOnboarding = true
                            } else {
                                showingCapture = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Fotoğraf Çekmeye Başla")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(16)
                        }
                        
                        // View tutorial button (always available)
                        Button(action: {
                            showingOnboarding = true
                        }) {
                            HStack {
                                Image(systemName: hasCompletedOnboarding ? "info.circle" : "play.circle")
                                Text(hasCompletedOnboarding ? "Nasıl Kullanılır?" : "Rehberi Göster")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    showingOnboarding = false
                    showingCapture = true
                }
            }
            .fullScreenCover(isPresented: $showingCapture) {
                CaptureFlowView(viewModel: CaptureViewModel())
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

#Preview {
    ContentView()
}
