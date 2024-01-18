//
//  Scened.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/28/23.
//

import SwiftUI
import VisionKit

struct LiveTextSupportEnvironmentKey: EnvironmentKey {
  static var defaultValue = true
}

extension EnvironmentValues {
  var liveTextSupported: LiveTextSupportEnvironmentKey.Value {
    get { self[LiveTextSupportEnvironmentKey.self] }
    set { self[LiveTextSupportEnvironmentKey.self] = newValue }
  }
}

extension Scene {
  func scened() -> some Scene {
    self.environment(\.liveTextSupported, ImageAnalyzer.isSupported)
  }
}
