//
//  ImageCollectionExternalCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import AdvanceCore
import SwiftUI

struct ImageCollectionExternalCommands: Commands {
  @FocusedValue(\.imagesQuickLook) private var quicklook

  var body: some Commands {
    CommandGroup(after: .saveItem) {
      Section {
        MenuItemToggle(toggle: quicklook ?? .init(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          ImageCollectionQuickLookView(isOn: $isOn)
        }.keyboardShortcut(.quicklook)
      }
    }
  }
}
