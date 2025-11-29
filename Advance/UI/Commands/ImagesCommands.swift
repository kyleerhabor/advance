//
//  ImagesCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesCommands: Commands {
  @AppStorage(StorageKeys.liveTextIcon) private var liveTextIcon
  @FocusedValue(\.imagesSidebarShow) private var sidebarShow
  @FocusedValue(\.imagesLiveTextIcon) private var imagesLiveTextIcon
  @FocusedValue(\.imagesLiveTextHighlight) private var liveTextHighlight

  var body: some Commands {
    SidebarCommands()
    ToolbarCommands()

    CommandMenu("Images.Commands.Image") {
      MenuItemButton(item: sidebarShow ?? AppMenuActionItem(identity: nil, enabled: false, action: noop)) {
        Text("Sidebar.Item.Show")
      }
      .keyboardShortcut(.sidebarShowItem)

      Section("Images.Commands.Image.LiveText") {
        MenuItemToggle(toggle: imagesLiveTextIcon ?? AppMenuToggleItem(identity: nil, enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Commands.Image.LiveText.Icon.Hide" : "Images.Commands.Image.LiveText.Icon.Show") {
            isOn.toggle()
          }
        }
        .keyboardShortcut(.liveTextIcon)

        MenuItemToggle(toggle: liveTextHighlight ?? AppMenuToggleItem(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Commands.Image.LiveText.Highlight.Hide" : "Images.Commands.Image.LiveText.Highlight.Show") {
            isOn.toggle()
          }
        }
        .keyboardShortcut(.liveTextHighlight)
      }
    }
  }
}
