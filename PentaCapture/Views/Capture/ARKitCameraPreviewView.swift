//
//  ARKitCameraPreviewView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 10.11.2025.
//

import SwiftUI
import ARKit
import SceneKit

/// ARKit camera preview view using ARSCNView
struct ARKitCameraPreviewView: UIViewRepresentable {
    let faceTrackingService: FaceTrackingService
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero, options: nil)
        
        // Configure ARSCNView
        arView.session = faceTrackingService.arSession
        arView.automaticallyUpdatesLighting = false
        arView.rendersCameraGrain = false
        arView.rendersMotionBlur = false
        
        // Empty scene (we only want camera background)
        arView.scene = SCNScene()
        
        // Hide statistics
        arView.showsStatistics = false
        
        // Important: Don't allow AR view to handle scene updates
        arView.delegate = context.coordinator
        
        print("✅ ARSCNView configured")
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Keep session reference updated
        if uiView.session != faceTrackingService.arSession {
            uiView.session = faceTrackingService.arSession
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        // Minimal delegate to prevent ARSCNView from adding its own content
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Do nothing - we don't want ARSCNView to modify the scene
        }
    }
}

