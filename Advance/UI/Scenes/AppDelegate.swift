//
//  AppDelegate.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AppKit
import AsyncAlgorithms
import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
@Observable
class AppDelegate: NSObject, NSApplicationDelegate {
  @ObservationIgnored let openChannel = AsyncChannel<[URL]>()
  @ObservationIgnored private var colorScheme: Task<Void, Never>!

  func applicationWillFinishLaunching(_ notification: Notification) {
    let app = notification.object as! NSApplication
    
    // Set the appearance of the app before any windows appear.
    setAppearance(for: app, colorScheme: Defaults[.colorScheme])

    // I personally think the context switch one needs to perform mentally when switching tabs outweights the benefit
    // of having less windows. The lack of animation is the greatest driving force, but also, Advance optimizes for
    // standalone windows. This places tabs at odds with Advance's design goals.
    NSWindow.allowsAutomaticWindowTabbing = false

    colorScheme = Task { [weak self] in
      for await colorScheme in Defaults.updates(.colorScheme, initial: false) {
        self?.setAppearance(for: NSApplication.shared, colorScheme: colorScheme)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    colorScheme.cancel()
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

  // For some reason, this method is invoked with urls in the following order from a drag and drop operation:
  //
  //   [A]
  //   [A, B]
  //   [C, A, B]
  //   [B, C, D, A]
  //   [B, C, D, E, A]
  //
  // This does not happen with Finder > File > Open With > Advance. Unless we can discover the reason this method was
  // invoked (that is, drag and drop or Finder open), I think keeping the buggy behavior is better than inverting it.
  func application(_ application: NSApplication, open urls: [URL]) {
    application.abortModal()

    Task {
      await self.openChannel.send(urls)
    }
  }

  func setAppearance(for app: NSApplication, colorScheme: DefaultColorScheme) {
    app.appearance = colorScheme.appearance
  }
}
