//
//  ImageCollectionExternalCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import SwiftUI

struct ImageCollectionExternalCommands: Commands {
  @FocusedValue(\.finderShow) private var showFinder
  @FocusedValue(\.finderOpen) private var openFinder
  @FocusedValue(\.quicklook) private var quicklook

  var body: some Commands {
    CommandGroup(after: .saveItem) {
      Section {
        MenuItemButton(item: showFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Show")
        }.keyboardShortcut(.showFinder)

        MenuItemToggle(toggle: quicklook ?? .init(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          ImageCollectionQuickLookView(isOn: $isOn)
        }.keyboardShortcut(.quicklook)
      }

      Section {
        MenuItemButton(item: openFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Open")
        }.keyboardShortcut(.openFinder)
      }
    }
  }
}
