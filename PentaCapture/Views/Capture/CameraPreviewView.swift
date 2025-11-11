//
//  CameraPreviewView.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import AVFoundation
import SwiftUI

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer
/// Used as fallback when ARKit face tracking is not available
struct CameraPreviewView: UIViewRepresentable {
  let cameraService: CameraService

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.backgroundColor = .black
    view.videoPreviewLayer.session = cameraService.captureSession
    view.videoPreviewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {
    // No updates needed
  }

  /// Custom UIView that hosts the preview layer
  class PreviewView: UIView {
    override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
      layer as! AVCaptureVideoPreviewLayer
    }
  }
}
