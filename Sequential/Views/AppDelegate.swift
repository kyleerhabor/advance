//
//  AppDelegate.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI
import os

class AppDelegate: NSObject, NSApplicationDelegate {
  // If we try to use @Environment(\.openWindow) in this delegate, we'll get a warning about it not being used in a
  // SwiftUI view (which will note that the value will not be updated). While it's not really a problem, we're better
  // off not worrying about what other side effects it may entail.
  var onOpenURL: ([PersistentURL]) -> Void = { _ in }

  func application(_ application: NSApplication, open urls: [URL]) {
    // For some reason, the first URL is *sometimes* at the end. I tried on a local copy of The Ancient Magus' Bride (https://anilist.co/manga/85435/The-Ancient-Magus-Bride)
    // and found, for that particular case, that when there are more than three URLs, the last URL is moved towards the
    // end. I'm not sure if this is a Sonoma bug.
    do {
      let urls = try urls.map { try PersistentURL($0) }

      onOpenURL(urls)
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
