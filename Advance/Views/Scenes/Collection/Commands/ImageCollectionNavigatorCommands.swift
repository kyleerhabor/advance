//
//  ImageCollectionNavigatorCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 3/10/24.
//

import SwiftUI

struct ImageCollectionNavigatorCommands: Commands {
  @FocusedValue(\.navigator) private var navigator

  var body: some Commands {
    CommandGroup(after: .toolbar) {
      Group {
        MenuItemButton(item: .init(identity: navigator?.action.identity, enabled: navigator?.enabled ?? false) {
          navigator?.action.action(.images)
        }) {
          Label("Images.Commands.Navigator.Images", systemImage: "photo.on.rectangle")
        }.keyboardShortcut(.navigatorImages)

        MenuItemButton(item: .init(identity: navigator?.action.identity, enabled: navigator?.enabled ?? false) {
          navigator?.action.action(.bookmarks)
        }) {
          Label("Images.Commands.Navigator.Bookmarks", systemImage: "bookmark")
        }.keyboardShortcut(.navigatorBookmarks)
      }.labelStyle(.titleAndIcon)
    }
  }
}
