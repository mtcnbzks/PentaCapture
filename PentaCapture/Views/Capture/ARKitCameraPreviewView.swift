//
//  ARKitCameraPreviewView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 10.11.2025.
//

import ARKit
import SceneKit
import SwiftUI

struct ARKitCameraPreviewView: UIViewRepresentable {
  let faceTrackingService: FaceTrackingService

  func makeUIView(context: Context) -> ARSCNView {
    let arView = ARSCNView(frame: .zero, options: nil)
    arView.session = faceTrackingService.arSession
    arView.automaticallyUpdatesLighting = false
    arView.rendersCameraGrain = false
    arView.rendersMotionBlur = false
    arView.scene = SCNScene()
    arView.showsStatistics = false
    arView.delegate = context.coordinator
    return arView
  }

  func updateUIView(_ uiView: ARSCNView, context: Context) {
    if uiView.session != faceTrackingService.arSession {
      uiView.session = faceTrackingService.arSession
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {}
  }
}
