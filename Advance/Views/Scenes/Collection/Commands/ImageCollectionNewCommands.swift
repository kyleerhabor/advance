//
//  ImageCollectionNewCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import Defaults
import SwiftUI

struct ImageCollectionNewCommands: Commands {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(\.openWindow) private var openWindow
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.open) private var open

  var body: some Commands {
    CommandGroup(after: .newItem) {
      MenuItemButton(item: open ?? .init(identity: nil, enabled: true) {
        let urls = Self.importFileItems()

        guard !urls.isEmpty else {
          return
        }

        Task {
          let collection = await ImageCollectionCommands.resolve(
            urls: urls,
            in: .init(),
            includingHiddenFiles: importHidden,
            includingSubdirectories: importSubdirectories
          )

          let id = UUID()

          manager.collections[id] = collection

          openWindow(value: id)
        }
      }) {
        Text("Open.Interactive")
      }.keyboardShortcut(.open)
    }
  }

  static func importFileItems() -> [URL] {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image]
    panel.identifier = .init(FileDialogOpenViewModifier.id)

    // We don't want panel.begin() since it creating a modeless window causes SwiftUI to not treat it like a window.
    // This is most obvious when there are no windows but the open dialog and the app is activated, creating a new
    // window for the scene.
    //
    // FIXME: For some reason, entering Command-Shit-. to show hidden files causes the service to crash.
    //
    // This only happens when using identifier. Interestingly, it happens in SwiftUI, too.
    guard panel.runModal() == .OK else {
      return []
    }

    return panel.urls
  }
}
