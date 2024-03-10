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
      Menu("Images.Command.Navigator") {
        MenuItemButton(item: .init(identity: navigator?.action.identity, enabled: navigator?.enabled ?? false) {
          navigator?.action.action(.images)
        }) {
          Text("Images.Command.Navigator.Images")
        }.keyboardShortcut(.navigatorImages)

        MenuItemButton(item: .init(identity: navigator?.action.identity, enabled: navigator?.enabled ?? false) {
          navigator?.action.action(.bookmarks)
        }) {
          Text("Images.Command.Navigator.Bookmarks")
        }.keyboardShortcut(.navigatorBookmarks)
      }
    }
  }
}
