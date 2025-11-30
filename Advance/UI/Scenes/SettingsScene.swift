//
//  SettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/2/24.
//

import SwiftUI

struct SettingsScene: Scene {
  var body: some Scene {
    Settings {
      SettingsView2()
        .windowed()
        .frame(width: 600)
    }
    .windowResizability(.contentSize)
  }
}
