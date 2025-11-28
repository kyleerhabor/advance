//
//  AppDelegate.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/30/23.
//

import AdvanceCore
import AppKit
import Defaults
import OSLog

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  // If we try to use @Environment(\.openWindow) in this delegate, we'll get a warning about it not being used in a
  // SwiftUI view.
  var onOpen: ([URL]) -> Void = noop

  func applicationWillFinishLaunching(_ notification: Notification) {
    let app = notification.object as! NSApplication

    // Set the appearance of the app before any windows appear.
    app.appearance = Defaults[.colorScheme].appearance

    // I personally think the context switch one needs to perform mentally when switching tabs outweights the benefit
    // of (potentially) having less windows. The lack of animation is the largest contributing factor, but also, imo,
    // Advance is not meant to be used with a lot of windows, unlike e.g. Finder where it's easy to get a dozen
    // windows with a similar UI enough.
    NSWindow.allowsAutomaticWindowTabbing = false
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    application.abortModal()

    onOpen(urls)
  }

  func applicationWillUpdate(_ notification: Notification) {
    let app = notification.object as! NSApplication

    // This is meant to prevent a bug in SwiftUI involving the toolbar in full-screen mode. For Advance, when the
    // unified toolbar is hidden in full-screen mode and the user selects "Customize Toolbar...", it temporarily appears.
    // However, when the customize modal is dismissed, SwiftUI does not hide the toolbar, resulting in it persisting
    // until the user exits full-screen mode.
    //
    // The solution presented here checks if the window is full-screened and visible, and, if so, hides the toolbar.
    // It's likely inefficient, given this delegate method is called very often; however, it does solve our problem.

    guard app.modalWindow == nil else {
      return
    }

    app.windows.forEach { window in
      guard window.isFullScreen(),
            let toolbar = window.toolbar, toolbar.isVisible else {
        return
      }

      toolbar.isVisible = false
    }
  }
}
