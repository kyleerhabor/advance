//
//  FoldersSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import SwiftUI

struct FoldersSettingsScene: Scene {
  static let id = "folders"

  var body: some Scene {
    Window("Settings.Accessory.Folders.Window.Title", id: Self.id) {
      FoldersSettingsView()
        .frame(width: 500, height: 250)
    }
    .windowToolbarStyle(.unifiedCompact)
    .windowResizability(.contentSize)
    .keyboardShortcut(.foldersSettings)
  }
}
