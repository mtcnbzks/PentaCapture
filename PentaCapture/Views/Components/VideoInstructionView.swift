//
//  VideoInstructionView.swift
//  PentaCapture
//
//  Video instruction player for showing guidance before specific capture angles
//

import SwiftUI
import AVKit
import UIKit

/// Shows a video instruction before certain capture angles
struct VideoInstructionView: View {
  let videoFileName: String
  let onComplete: () -> Void
  
  @State private var player: AVPlayer?
  @State private var isVideoFinished = false
  @State private var showSkipButton = false
  
  var body: some View {
    ZStack {
      // Custom video player without controls
      if let player = player {
        CleanVideoPlayerView(player: player)
          .ignoresSafeArea()
          .onAppear {
            player.play()
            
            // Show skip button after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              withAnimation {
                showSkipButton = true
              }
            }
          }
      } else {
        // Loading state
        ZStack {
          Color.black.ignoresSafeArea()
          
          ProgressView()
            .tint(.white)
            .scaleEffect(1.5)
        }
      }
      
      // Skip/Continue button
      VStack {
        Spacer()
        
        if showSkipButton || isVideoFinished {
          Button(action: {
            onComplete()
          }) {
            HStack(spacing: 12) {
              Image(systemName: isVideoFinished ? "checkmark.circle.fill" : "forward.fill")
                .font(.system(size: 20, weight: .semibold))
              
              Text(isVideoFinished ? "Devam Et" : "Atla")
                .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            )
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .padding(.bottom, 50)
        }
      }
    }
    .onAppear {
      setupPlayer()
    }
    .onDisappear {
      cleanupPlayer()
    }
  }
  
  // MARK: - Player Setup
  
  private func setupPlayer() {
    guard let url = Bundle.main.url(forResource: videoFileName, withExtension: nil) else {
      print("❌ Video file not found: \(videoFileName)")
      // Auto-skip if video not found
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        onComplete()
      }
      return
    }
    
    print("📹 Loading video: \(videoFileName)")
    
    let playerItem = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: playerItem)
    
    // Observe when video finishes
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      print("✅ Video finished playing")
      withAnimation {
        isVideoFinished = true
      }
    }
    
    self.player = player
  }
  
  private func cleanupPlayer() {
    player?.pause()
    player = nil
    NotificationCenter.default.removeObserver(self)
  }
}

// MARK: - Clean Video Player (No Controls)

/// Custom video player without any playback controls - looks professional
struct CleanVideoPlayerView: UIViewRepresentable {
  let player: AVPlayer
  
  func makeUIView(context: Context) -> PlayerUIView {
    let view = PlayerUIView()
    view.player = player
    return view
  }
  
  func updateUIView(_ uiView: PlayerUIView, context: Context) {
    uiView.player = player
  }
}

/// UIView that uses AVPlayerLayer as its backing layer
class PlayerUIView: UIView {
  
  // Override the property to make AVPlayerLayer the view's backing layer
  override static var layerClass: AnyClass {
    return AVPlayerLayer.self
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }
  
  private func setupView() {
    // Set black background for professional look
    backgroundColor = .black
    playerLayer.backgroundColor = UIColor.black.cgColor
  }
  
  // The associated player object
  var player: AVPlayer? {
    get {
      return playerLayer.player
    }
    set {
      playerLayer.player = newValue
      // Set video gravity to maintain aspect ratio with black letterboxing
      playerLayer.videoGravity = .resizeAspect
    }
  }
  
  private var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }
}

// MARK: - Preview

struct VideoInstructionView_Previews: PreviewProvider {
  static var previews: some View {
    VideoInstructionView(videoFileName: "KısaMOV.mov") {
      print("Video completed")
    }
  }
}

