//
//  AppScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/4/24.
//

import SwiftUI

struct AppScene: Scene {
  var body: some Scene {
    ImageCollectionScene()
      .handlesExternalEvents(matching: [])

    Settings {
      SettingsView()
    }
  }
}
