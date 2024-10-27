//
//  ImageCollectionEditCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import AdvanceCore
import SwiftUI

struct ImageCollectionEditCommands: Commands {
  @FocusedValue(\.sidebarSearch) private var sidebarSearch

  var body: some Commands {
    CommandGroup(after: .textEditing) {
      MenuItemButton(item: sidebarSearch ?? .init(identity: nil, enabled: false, action: noop)) {
        Text("Search.Interaction")
      }.keyboardShortcut(.searchSidebar)
    }
  }
}
