//
//  ImageCollectionWindowCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/3/24.
//

import AdvanceCore
import Defaults
import SwiftUI

struct ImageCollectionWindowCommands: Commands {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate

  var body: some Commands {
    CommandGroup(after: .windowArrangement) {
      // This little hack allows us to do stuff with the UI on startup (since it's always called).
      Color.clear.onAppear {
        delegate.onOpen = { urls in
          Task {
            let collection = await ImageCollectionCommands.resolve(
              urls: urls,
              in: .init(),
              includingHiddenFiles: false,
              includingSubdirectories: true
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
