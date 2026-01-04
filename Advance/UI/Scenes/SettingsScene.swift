//
//  SettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/2/24.
//

import Combine
import SwiftUI

struct SettingsScene: Scene {
  @Environment(AppModel.self) private var app
  @FocusedValue(\.commandScene) private var scene

  var body: some Scene {
    Settings {
      SettingsView2()
        .windowed()
        .frame(width: 600)
    }
    .windowResizability(.contentSize)
    .onChange(of: self.scene?.bookmark.isOn) {
      let isOn = self.scene.map(\.bookmark.isOn) ?? false
      self.app.isBookmarkedSet = self.app.isBookmarked != isOn
      self.app.isBookmarked = isOn
    }
    .onChange(of: self.app.isBookmarked) {
      guard !self.app.isBookmarkedSet else {
        self.app.isBookmarkedSet = false

        return
      }

      guard let scene = self.scene else {
        return
      }

      self.app.commandsSubject.send(AppModelCommand(action: .bookmark, sceneID: scene.id))
    }
    .onChange(of: self.scene?.liveTextIcon.isOn) {
      let isOn = self.scene.map(\.liveTextIcon.isOn) ?? false
      self.app.isSupplementaryInterfaceVisibleSet = self.app.isSupplementaryInterfaceVisible != isOn
      self.app.isSupplementaryInterfaceVisible = isOn
    }
    .onChange(of: self.app.isSupplementaryInterfaceVisible) {
      guard !self.app.isSupplementaryInterfaceVisibleSet else {
        self.app.isSupplementaryInterfaceVisibleSet = false

        return
      }

      guard let scene = self.scene else {
        return
      }

      self.app.commandsSubject.send(AppModelCommand(action: .toggleLiveTextIcon, sceneID: scene.id))
    }
    .onChange(of: self.scene?.liveTextHighlight.isOn) {
      let isOn = self.scene.map(\.liveTextHighlight.isOn) ?? false
      self.app.isSelectableItemsHighlightedSet = self.app.isSelectableItemsHighlighted != isOn
      self.app.isSelectableItemsHighlighted = isOn
    }
    .onChange(of: self.app.isSelectableItemsHighlighted) {
      guard !self.app.isSelectableItemsHighlightedSet else {
        self.app.isSelectableItemsHighlightedSet = false

        return
      }

      guard let scene = self.scene else {
        return
      }

      self.app.commandsSubject.send(AppModelCommand(action: .toggleLiveTextHighlight, sceneID: scene.id))
    }
  }
}
