//
//  AudioFeedbackService.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import AVFoundation
import UIKit
import Combine

/// Types of audio feedback
enum FeedbackSound {
    case proximity(progress: Double) // Pitch varies with progress (0.0 to 1.0)
    case locked // Position locked
    case countdown(number: Int) // 3, 2, 1
    case captured // Photo taken
    case error // Something went wrong
    
    var systemSoundID: SystemSoundID? {
        switch self {
        case .locked:
            return 1305 // Success sound
        case .captured:
            return 1108 // Camera shutter sound
        case .error:
            return 1053 // Error sound
        default:
            return nil
        }
    }
}

/// Service responsible for providing audio feedback during capture
class AudioFeedbackService: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled = true
    @Published var volume: Float = 1.0
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isEngineRunning = false
    
    private var lastProximityProgress: Double = 0.0
    private var proximityTimer: Timer?
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let playerNode = playerNode else { return }
        
        audioEngine.attach(playerNode)
        
        // Use mixer's output format for proper channel matching
        let mixer = audioEngine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        audioEngine.connect(playerNode, to: mixer, format: format)
    }
    
    // MARK: - Audio Engine Control
    private func startEngineIfNeeded() {
        guard let audioEngine = audioEngine, !isEngineRunning else { return }
        
        do {
            try audioEngine.start()
            isEngineRunning = true
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func stopEngine() {
        guard let audioEngine = audioEngine, isEngineRunning else { return }
        
        audioEngine.stop()
        isEngineRunning = false
    }
    
    // MARK: - Feedback Methods
    
    /// Play feedback sound
    func playFeedback(_ sound: FeedbackSound) {
        guard isEnabled else { return }
        
        switch sound {
        case .proximity(let progress):
            playProximitySound(progress: progress)
            
        case .locked:
            playSystemSound(.locked)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
        case .countdown(let number):
            playCountdownBeep(for: number)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case .captured:
            playSystemSound(.captured)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
        case .error:
            playSystemSound(.error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Proximity Sound
    private func playProximitySound(progress: Double) {
        // Throttle proximity sound updates
        guard abs(progress - lastProximityProgress) > 0.05 else { return }
        lastProximityProgress = progress
        
        // Map progress (0.0 to 1.0) to frequency (200 Hz to 800 Hz)
        let minFrequency: Float = 200.0
        let maxFrequency: Float = 800.0
        let frequency = minFrequency + Float(progress) * (maxFrequency - minFrequency)
        
        playTone(frequency: frequency, duration: 0.1)
        
        // Haptic feedback based on progress
        if progress > 0.9 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if progress > 0.6 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    /// Start continuous proximity feedback
    func startProximityFeedback() {
        proximityTimer?.invalidate()
        proximityTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // This timer is just to keep the feedback loop running
            // Actual updates come from external calls to playFeedback(.proximity)
        }
    }
    
    /// Stop continuous proximity feedback
    func stopProximityFeedback() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        lastProximityProgress = 0.0
    }
    
    // MARK: - Tone Generation
    private func playTone(frequency: Float, duration: TimeInterval) {
        guard let playerNode = playerNode else { return }
        
        startEngineIfNeeded()
        
        let sampleRate = 44100.0
        let amplitude: Float = 0.3 * volume
        let frameCount = UInt32(duration * sampleRate)
        
        // Use stereo format to match mixer format (2 channels)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let angularFrequency = Float(2.0 * Double.pi) * frequency / Float(sampleRate)
        
        // Fill both channels with the same data (stereo)
        for channel in 0..<Int(format.channelCount) {
            let channelData = floatChannelData[channel]
            for frame in 0..<Int(frameCount) {
                let sample = sin(angularFrequency * Float(frame)) * amplitude
                channelData[frame] = sample
            }
        }
        
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    // MARK: - Countdown Beeps
    private func playCountdownBeep(for number: Int) {
        // Different frequencies for different numbers
        let frequency: Float = switch number {
        case 3: 440.0  // A4
        case 2: 523.25 // C5
        case 1: 659.25 // E5
        default: 440.0
        }
        
        playTone(frequency: frequency, duration: 0.15)
    }
    
    // MARK: - System Sounds
    private func playSystemSound(_ sound: FeedbackSound) {
        guard let soundID = sound.systemSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - Sequence Methods
    
    /// Play countdown sequence (3, 2, 1)
    func playCountdownSequence(completion: @escaping () -> Void) {
        guard isEnabled else {
            completion()
            return
        }
        
        playFeedback(.countdown(number: 3))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.playFeedback(.countdown(number: 2))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.playFeedback(.countdown(number: 1))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    completion()
                }
            }
        }
    }
    
    /// Play capture sequence (shutter + success)
    func playCaptureSequence() {
        playFeedback(.captured)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // MARK: - Settings
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
    }
    
    func toggleEnabled() {
        isEnabled.toggle()
        
        if !isEnabled {
            stopProximityFeedback()
            stopEngine()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        proximityTimer?.invalidate()
        stopEngine()
    }
}

// MARK: - Haptic Feedback Extension
extension AudioFeedbackService {
    /// Provide haptic feedback for validation progress
    func provideHapticFeedback(for status: ValidationStatus) {
        switch status {
        case .locked:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .valid:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .adjusting(let progress):
            if progress > 0.8 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        case .invalid:
            break // No haptic for invalid
        }
    }
}

