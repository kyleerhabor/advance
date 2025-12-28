//
//  AppDelegate.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AppKit
import Combine
import Defaults

@MainActor
class AppDelegate2: NSObject, NSApplicationDelegate, ObservableObject {
  let open = PassthroughSubject<[URL], Never>()
  var colorSchemeAppearance: Task<Void, Never>!

  func applicationWillFinishLaunching(_ notification: Notification) {
    let app = notification.object as! NSApplication
    setAppearance(for: app, colorScheme: Defaults[.colorScheme])

    // I personally think the context switch one needs to perform mentally when switching tabs outweights the benefit
    // of having less windows. The lack of animation is the greatest driving force, but also, Advance optimizes for
    // standalone windows. This places tabs at odds with Advance's design goals.
    NSWindow.allowsAutomaticWindowTabbing = false

    colorSchemeAppearance = Task { [weak self] in
      for await colorScheme in Defaults.updates(.colorScheme, initial: false) {
        self?.setAppearance(for: NSApplication.shared, colorScheme: colorScheme)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    colorSchemeAppearance.cancel()
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    open.send(urls)
  }

  func setAppearance(for app: NSApplication, colorScheme: DefaultColorScheme) {
    app.appearance = colorScheme.appearance
  }
}
