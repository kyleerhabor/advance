//
//  AppCommands.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/29/23.
//

import SwiftUI
import os

struct AppCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var windowOpened: () -> Void

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      // Is there a way to grab the default menu items used for a viewable-only document-based app? I'd rather not
      // hard-code values (specifically like this) that may change over time.
      Button("Open...") {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        // For some reason, the panel does not like being called in a Task (complains about not being run on the main
        // thread, even though it's worked before).
        panel.begin { res in
          guard res == .OK else {
            return
          }

          do {
            let urls = try panel.urls.map { try PersistentURL($0) }
            
            openWindow(value: Sequence(from: urls))
            windowOpened()
          } catch {
            Logger.ui.error("\(error)")
          }
        }
      }.keyboardShortcut("o", modifiers: .command)
    }
  }
}
