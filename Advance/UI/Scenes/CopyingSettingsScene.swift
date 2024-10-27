//
//  CopyingSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import SwiftUI

struct CopyingSettingsScene: Scene {
  static let id = "copying"

  var body: some Scene {
    Window("Settings.Accessory.Copying.Window.Title", id: Self.id) {
      CopyingSettingsView()
        .frame(width: 500, height: 250)
    }
    .windowToolbarStyle(.unifiedCompact)
    .windowResizability(.contentSize)
    .keyboardShortcut(.copyingSettings)
  }
}
