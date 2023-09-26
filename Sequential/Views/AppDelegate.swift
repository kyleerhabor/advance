//
//  AppDelegate.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import AppKit
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  // If we try to use @Environment(\.openWindow) in this delegate, we'll get a warning about it not being used in a
  // SwiftUI view (which will note that the value will not be updated). While it's not really a problem, we're better
  // off not worrying about what other side effects it may entail.
  var onOpen: ([URL]) -> Void = { _ in }

  func application(_ application: NSApplication, open urls: [URL]) {
    // TODO: Support opening folders.
    //
    // I presume this would require using the relativeTo parameter when creating and resolving bookmarks.
    onOpen(urls)
  }
}

func openFinder(selecting url: URL) {
  openFinder(selecting: [url])
}

func openFinder(selecting urls: [URL]) {
  NSWorkspace.shared.activateFileViewerSelecting(urls)
}

func openFinder(in url: URL) -> Bool {
  NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.string)
}

func openFinder(at url: URL) {
  if !openFinder(in: url) {
    Logger.ui.info("Failed to open Finder in folder \"\(url.string)\". Fallbacking to selection...")

    openFinder(selecting: url)
  }
}
