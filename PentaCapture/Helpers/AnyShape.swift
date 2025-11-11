//
//  AnyShape.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

/// Type-erased Shape wrapper
struct AnyShape: Shape {
  private let _path: (CGRect) -> Path

  init<S: Shape>(_ shape: S) {
    _path = { rect in
      shape.path(in: rect)
    }
  }

  func path(in rect: CGRect) -> Path {
    _path(rect)
  }
}
