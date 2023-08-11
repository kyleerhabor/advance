//
//  AppDelegate.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate {
  // If we try to use @Environment(\.openWindow) in this delegate, we'll get a warning about it not being used in a
  // SwiftUI view (which will note that the value will not be updated). While it's not really a problem, we're better
  // off not worrying about what other side effects it may entail.
  var onOpenURL: (Sequence) -> Void = { _ in }

  func application(_ application: NSApplication, open urls: [URL]) {
    do {
      let bookmarks = try urls.map { try $0.bookmark() }

      onOpenURL(.init(bookmarks: bookmarks))
    } catch {
      Logger.ui.error("\(error)")
    }
  }
}

func openFinder(for url: URL) {
  openFinder(for: [url])
}

func openFinder(for urls: [URL]) {
  NSWorkspace.shared.activateFileViewerSelecting(urls)
}
