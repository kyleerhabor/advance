//
//  FoldersSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import SwiftUI

struct FoldersSettingsScene: Scene {
  @Environment(FoldersSettingsModel2.self) private var folders
  static let id = "folders"

  var body: some Scene {
    Window("Settings.Accessory.Folders.Window.Title", id: Self.id) {
      FoldersSettingsView2()
        .frame(width: 500, height: 250)
        .focusedValue(folders)
    }
    .windowToolbarStyle(.unifiedCompact)
    .windowResizability(.contentSize)
    .keyboardShortcut(.foldersSettings)
    .commandsReplaced {
      FolderSettingsCommands()
    }
  }
}
