//
//  ImageCollectionImageCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import SwiftUI

struct ImageCollectionImageCommands: Commands {
  @FocusedValue(\.currentImageShow) private var currentImageShow
  @FocusedValue(\.bookmark) private var bookmark
  @FocusedValue(\.liveTextIcon) private var liveTextIcon
  @FocusedValue(\.liveTextHighlight) private var liveTextHighlight

  var body: some Commands {
    CommandMenu("Images.Command.Section.Image") {
      Section {
        MenuItemButton(item: currentImageShow ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Sidebar.Item.Show")
        }.keyboardShortcut(.showCurrentImage)
      }

      Section {
        MenuItemToggle(toggle: bookmark ?? .init(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Command.Bookmark.Remove" : "Images.Command.Bookmark.Add") {
            isOn.toggle()
          }
        }.keyboardShortcut(.bookmark)
      }

      Section("Images.Command.Section.LiveText") {
        MenuItemButton(item: liveTextIcon.map(AppMenuItem.init(toggle:)) ?? .init(identity: nil, enabled: false, action: noop)) {
          Text(liveTextIcon?.state == true ? "Images.Command.LiveText.Icon.Hide" : "Images.Command.LiveText.Icon.Show")
        }.keyboardShortcut(.liveTextIcon)

        MenuItemButton(item: liveTextHighlight.map(AppMenuItem.init(toggle:)) ?? .init(identity: [], enabled: false, action: noop)) {
          Text(liveTextHighlight?.state == true ? "Images.Command.LiveText.Highlight.Hide" : "Images.Command.LiveText.Highlight.Show")
        }.keyboardShortcut(.liveTextHighlight)
      }
    }
  }
}
