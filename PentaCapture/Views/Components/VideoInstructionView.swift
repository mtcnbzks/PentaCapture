//
//  VideoInstructionView.swift
//  PentaCapture
//
//  Video instruction player for showing guidance before specific capture angles
//

import SwiftUI
import AVKit
import UIKit
import Combine

/// Shows a video instruction before certain capture angles
struct VideoInstructionView: View {
  let videoFileName: String
  let onComplete: () -> Void
  
  @State private var player: AVPlayer?
  @State private var playerItem: AVPlayerItem?
  @State private var isVideoFinished = false
  @State private var showSkipButton = false
  @State private var showReplayButton = false
  @State private var videoLoadingState: VideoLoadingState = .loading
  @State private var cancellables = Set<AnyCancellable>()
  
  // Video loading states
  enum VideoLoadingState {
    case loading
    case ready
    case failed(String)
  }
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      // Show content based on loading state
      switch videoLoadingState {
      case .loading:
        // Loading state
        VStack(spacing: 20) {
          ProgressView()
            .tint(.white)
            .scaleEffect(1.5)
          
          Text("Video yükleniyor...")
            .foregroundColor(.white.opacity(0.8))
            .font(.system(size: 16))
        }
        
      case .ready:
        // Video player
        if let player = player {
          CleanVideoPlayerView(player: player)
            .ignoresSafeArea()
            .onAppear {
              print("📹 Starting video playback...")
              player.play()
              
              // Show replay button immediately when video starts
              withAnimation {
                showReplayButton = true
              }
              
              // Show skip button after 2 seconds
              DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                  showSkipButton = true
                }
              }
            }
        }
        
      case .failed(let errorMessage):
        // Error state
        VStack(spacing: 24) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 60))
            .foregroundColor(.yellow)
          
          Text("Video Yüklenemedi")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.white)
          
          Text(errorMessage)
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
          
          Button(action: {
            print("⏭️ Skipping failed video...")
            onComplete()
          }) {
            Text("Devam Et")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.white)
              .padding(.horizontal, 32)
              .padding(.vertical, 14)
              .background(
                Capsule()
                  .fill(Color.blue)
              )
          }
          .padding(.top, 8)
        }
      }
      
      // Control buttons - only show for ready state
      if case .ready = videoLoadingState {
        VStack {
          Spacer()
          
          HStack(spacing: 20) {
            // Replay button - show when video starts playing
            if showReplayButton {
              Button(action: {
                replayVideo()
              }) {
                HStack(spacing: 8) {
                  Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                  
                  Text("Yeniden Oynat")
                    .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                  Capsule()
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                      Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                )
              }
              .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Skip/Continue button
            if showSkipButton || isVideoFinished {
              Button(action: {
                onComplete()
              }) {
                HStack(spacing: 10) {
                  Image(systemName: isVideoFinished ? "checkmark.circle.fill" : "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                  
                  Text(isVideoFinished ? "Devam Et" : "Atla")
                    .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
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
            }
          }
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
  
  // MARK: - Player Controls
  
  /// Replay the video from the beginning
  private func replayVideo() {
    guard let player = player else { return }
    
    print("🔄 Replaying video from beginning...")
    
    // Seek to the beginning
    player.seek(to: .zero) { finished in
      if finished {
        print("✅ Seeked to beginning, starting playback...")
        player.play()
        
        // Reset video finished state
        withAnimation {
          isVideoFinished = false
        }
      }
    }
  }
  
  // MARK: - Player Setup
  
  private func setupPlayer() {
    // Step 1: Verify video file exists
    guard let url = Bundle.main.url(forResource: videoFileName, withExtension: nil) else {
      print("❌ Video file not found in bundle: \(videoFileName)")
      videoLoadingState = .failed("Video dosyası bulunamadı. Lütfen uygulamayı yeniden yükleyin.")
      // Auto-skip after showing error briefly
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        onComplete()
      }
      return
    }
    
    print("📹 Loading video from: \(url.path)")
    print("📹 Video file name: \(videoFileName)")
    
    // Step 2: Verify file exists at path
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else {
      print("❌ Video file does not exist at path: \(url.path)")
      videoLoadingState = .failed("Video dosyası yolda bulunamadı.")
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        onComplete()
      }
      return
    }
    
    // Step 3: Get file info for diagnostics
    do {
      let attributes = try fileManager.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      print("📹 Video file size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
    } catch {
      print("⚠️ Could not read file attributes: \(error.localizedDescription)")
    }
    
    // Step 4: Create AVAsset to inspect video properties
    let asset = AVAsset(url: url)
    
    // Step 5: Create player item with the asset
    let playerItem = AVPlayerItem(asset: asset)
    self.playerItem = playerItem
    
    // Step 6: Observe player item status using Combine
    // Per Apple documentation: Status indicates if item is ready to play
    playerItem.publisher(for: \.status)
      .receive(on: DispatchQueue.main)
      .sink { [self] status in
        print("📹 AVPlayerItem status changed: \(statusString(status))")
        
        switch status {
        case .unknown:
          print("⏳ Video status: Unknown (loading...)")
          videoLoadingState = .loading
          
        case .readyToPlay:
          print("✅ Video status: Ready to play")
          
          // Log video track information for diagnostics
          logVideoTrackInfo(asset: asset)
          
          videoLoadingState = .ready
          
        case .failed:
          let errorMessage = playerItem.error?.localizedDescription ?? "Bilinmeyen hata"
          print("❌ Video status: Failed - \(errorMessage)")
          
          // Log detailed error information
          if let error = playerItem.error {
            let nsError = error as NSError
            print("❌ Error domain: \(nsError.domain)")
            print("❌ Error code: \(nsError.code)")
            print("❌ Error description: \(error.localizedDescription)")
            
            // Check error log for more details
            if let errorLog = playerItem.errorLog() {
              print("❌ Error log events: \(errorLog.events.count)")
              for event in errorLog.events {
                print("❌   - \(event.errorComment ?? "No comment")")
                print("❌   - Domain: \(event.errorDomain ?? "Unknown")")
              }
            }
          }
          
          videoLoadingState = .failed("Video yüklenemedi: \(errorMessage)")
          
          // Auto-skip after showing error
          DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onComplete()
          }
          
        @unknown default:
          print("⚠️ Video status: Unknown case")
          videoLoadingState = .failed("Bilinmeyen video durumu")
        }
      }
      .store(in: &cancellables)
    
    // Step 7: Create player with the item
    let player = AVPlayer(playerItem: playerItem)
    self.player = player
    
    // Step 8: Observe when video finishes
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
    
    // Step 9: Observe playback stalls (might indicate codec/format issues)
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: playerItem,
      queue: .main
    ) { _ in
      print("⚠️ Video playback stalled - possible codec or streaming issue")
    }
    
    print("📹 Player setup completed, waiting for status...")
  }
  
  // Helper to convert status enum to readable string
  private func statusString(_ status: AVPlayerItem.Status) -> String {
    switch status {
    case .unknown: return "unknown"
    case .readyToPlay: return "readyToPlay"
    case .failed: return "failed"
    @unknown default: return "unknown_default"
    }
  }
  
  // Log video track information for diagnostics
  private func logVideoTrackInfo(asset: AVAsset) {
    Task {
      do {
        // Load tracks asynchronously (iOS 15+)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        print("📹 Video track information:")
        print("   - Number of video tracks: \(tracks.count)")
        
        for (index, track) in tracks.enumerated() {
          let naturalSize = try await track.load(.naturalSize)
          let formatDescriptions = try await track.load(.formatDescriptions)
          
          print("   - Track \(index):")
          print("     • Resolution: \(naturalSize.width) x \(naturalSize.height)")
          print("     • Format descriptions: \(formatDescriptions.count)")
          
          // Get codec information
          for formatDesc in formatDescriptions {
            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)
            let codecString = fourCharCodeToString(mediaSubType)
            print("     • Codec: \(codecString)")
            
            // Check for common codecs
            switch codecString {
            case "hvc1", "hev1":
              print("     ⚠️ HEVC codec detected - may have compatibility issues on older devices")
            case "avc1", "avc3":
              print("     ✅ H.264 codec detected - widely compatible")
            default:
              print("     ℹ️ Codec type: \(codecString)")
            }
          }
        }
      } catch {
        print("⚠️ Could not load video track info: \(error.localizedDescription)")
      }
    }
  }
  
  // Convert FourCharCode to readable string
  private func fourCharCodeToString(_ code: FourCharCode) -> String {
    let chars = [
      UInt8((code >> 24) & 0xFF),
      UInt8((code >> 16) & 0xFF),
      UInt8((code >> 8) & 0xFF),
      UInt8(code & 0xFF)
    ]
    return String(bytes: chars, encoding: .ascii) ?? "????"
  }
  
  private func cleanupPlayer() {
    print("🧹 Cleaning up video player...")
    player?.pause()
    player = nil
    playerItem = nil
    cancellables.removeAll()
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
    
    // Per Apple documentation: Ensure layer is properly configured
    playerLayer.contentsGravity = .resizeAspect
    
    print("📹 PlayerUIView setup completed")
    print("   - Layer class: \(type(of: layer))")
    print("   - Background color: \(backgroundColor?.description ?? "nil")")
  }
  
  // Ensure proper layout when bounds change
  override func layoutSubviews() {
    super.layoutSubviews()
    
    // Per Apple documentation: AVPlayerLayer frame should match view bounds
    playerLayer.frame = bounds
    
    print("📹 PlayerUIView layout updated")
    print("   - Bounds: \(bounds)")
    print("   - Player layer frame: \(playerLayer.frame)")
  }
  
  // The associated player object
  var player: AVPlayer? {
    get {
      return playerLayer.player
    }
    set {
      playerLayer.player = newValue
      
      // Per Apple documentation: Set video gravity to control content scaling
      // .resizeAspect maintains aspect ratio with black letterboxing
      // This is the most compatible option for all devices
      playerLayer.videoGravity = .resizeAspect
      
      print("📹 Player assigned to layer")
      print("   - Player: \(newValue != nil ? "Set" : "Nil")")
      print("   - Video gravity: \(playerLayer.videoGravity.rawValue)")
      
      // Verify player layer is ready for display
      if newValue != nil {
        print("   - Layer is ready for video display")
        
        // Force layout update to ensure proper rendering
        setNeedsLayout()
        layoutIfNeeded()
      }
    }
  }
  
  private var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }
}

// MARK: - Preview

struct VideoInstructionView_Previews: PreviewProvider {
  static var previews: some View {
    VideoInstructionView(videoFileName: "instruction_short.mov") {
      print("Video completed")
    }
  }
}

