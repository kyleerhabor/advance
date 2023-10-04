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

  func applicationWillFinishLaunching(_ notification: Notification) {
    let prior = #selector(NSWindowDelegate.window(_:willUseFullScreenPresentationOptions:))
    let selector = #selector(WindowDelegate.window(_:willUseFullScreenPresentationOptions:))
    let method = class_getClassMethod(WindowDelegate.self, selector)!
    let impl = method_getImplementation(method)

    class_addMethod(NSWindowController.self, prior, impl, nil)

    // I personally think the context switch one needs to perform mentally when switching tabs outweights the benefit
    // of (potentially) having less windows. The lack of animation is the largest contributing factor, but also, imo,
    // Sequential is not meant to be used with a lot of windows, unlike e.g. Finder where it's easy to get a dozen
    // windows where the UI is similar enough. It's also not totally compatible with NSWindowDelegate's window(_:willUseFullScreenPresentationOptions:)
    // method, since it can sometimes get stuck until the user moves to another space and then back.
    NSWindow.allowsAutomaticWindowTabbing = false
  }

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
