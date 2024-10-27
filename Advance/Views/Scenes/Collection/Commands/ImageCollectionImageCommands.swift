//
//  ImageCollectionImageCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import AdvanceCore
import SwiftUI

struct ImageCollectionImageCommands: Commands {
  @FocusedValue(\.bookmark) private var bookmark

  var body: some Commands {
    CommandMenu("Images.Command.Section.Image") {
      Section {
        MenuItemToggle(toggle: bookmark ?? .init(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Command.Bookmark.Remove" : "Images.Command.Bookmark.Add") {
            isOn.toggle()
          }
        }.keyboardShortcut(.bookmark)
      }
    }
  }
}
