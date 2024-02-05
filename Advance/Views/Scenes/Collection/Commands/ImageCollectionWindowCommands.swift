//
//  ImageCollectionWindowCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import Defaults
import SwiftUI

struct ImageCollectionWindowCommands: Commands {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.windowSizeReset) private var windowSizeReset

  var body: some Commands {
    CommandGroup(after: .windowSize) {
      MenuItemButton(item: windowSizeReset ?? .init(identity: nil, enabled: false, action: noop)) {
        Text("Images.Command.Window.Size.Reset")
      }.keyboardShortcut(.resetWindowSize)
    }

    CommandGroup(after: .windowArrangement) {
      // This little hack allows us to do stuff with the UI on startup (since it's always called).
      Color.clear.onAppear {
        delegate.onOpen = { urls in
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
        }
      }
    }
  }
}
