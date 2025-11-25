//
//  PentaCaptureApp.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    .portrait
  }
}

@main
struct PentaCaptureApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    StorageService().cleanupOldUserDefaultsData()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
