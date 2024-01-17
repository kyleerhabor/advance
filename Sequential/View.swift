//
//  View.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/31/23.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

extension NSWindow {
  func isFullScreen() -> Bool {
    self.styleMask.contains(.fullScreen)
  }
}

extension EdgeInsets {
  // Normally, NSTableView's style can just be set to .plain to take up the full size of the container. List, for some
  // reason, doesn't want to do that, so I have to do this little dance. I have no idea if this will transfer well to
  // other devices.
  static let listRow = Self(top: 0, leading: -8, bottom: 0, trailing: -9)

  init(_ insets: Double) {
    self.init(top: insets, leading: insets, bottom: insets, trailing: insets)
  }

  init(vertical: Double, horizontal: Double) {
    self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
  }

  init(horizontal: Double, top: Double, bottom: Double) {
    self.init(top: top, leading: horizontal, bottom: bottom, trailing: horizontal)
  }
}

extension Color {
  static let tertiaryLabel = Self(nsColor: .tertiaryLabelColor)
}

extension KeyboardShortcut {
  static let open = Self("o")
  static let finder = Self("r")
  static let quicklook = Self("y")
  static let fullScreen = Self("f", modifiers: [.command, .control])
}

extension View {
  func visible(_ visible: Bool) -> some View {
    self.opacity(visible ? 1 : 0)
  }
}

extension Binding {
  init(_ base: Binding<Value?>, defaultValue: Value) {
    self.init {
      base.wrappedValue ?? defaultValue
    } set: { value in
      base.wrappedValue = value
    }
  }
}

struct FileDialogOpenViewModifier: ViewModifier {
  static let id = "open"

  func body(content: Content) -> some View {
    content.fileDialogCustomizationID(Self.id)
  }
}

struct FileDialogCopyViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .fileDialogCustomizationID("copy")
      .fileDialogConfirmationLabel("Copy")
  }
}

struct FileDialogCopyingViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .fileDialogCustomizationID("copying")
      .fileDialogConfirmationLabel("Add")
  }
}

extension View {
  func fileDialogOpen() -> some View {
    self.modifier(FileDialogOpenViewModifier())
  }

  func fileDialogCopy() -> some View {
    self.modifier(FileDialogCopyViewModifier())
  }

  func fileDialogCopying() -> some View {
    self.modifier(FileDialogCopyingViewModifier())
  }
}

extension FileManager {
  func contents(at url: URL, options: DirectoryEnumerationOptions) -> [URL] {
    self
      .enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: options)?
      .contents() ?? []
  }
}

extension FileManager.DirectoryEnumerationOptions {
  init(includingHiddenFiles hidden: Bool, includingSubdirectories subdirectories: Bool) {
    // Packages are directories presented as files in Finder (e.g. an app). Generally, there is no reason to descend
    // into them, as their structures are usually unique and meant for installers.
    self = .skipsPackageDescendants

    if !hidden {
      self.insert(.skipsHiddenFiles)
    }

    if !subdirectories {
      self.insert(.skipsSubdirectoryDescendants)
    }
  }
}

extension NSWindow {
  func setToolbarVisibility(_ visible: Bool) {
    self.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = visible ? 1 : 0

    // For some reason, full screen windows in light mode draw a slight line under the top of the screen after
    // scrolling for a bit. This doesn't occur in dark mode, which is interesting.
    //
    // FIXME: For some reason, the title bar separator does not animate.
    self.animator().titlebarSeparatorStyle = visible && !self.isFullScreen() ? .automatic : .none
  }
}

struct ToolbarHiddenViewModifier: ViewModifier {
  @Environment(WindowCapture.self) private var capture
  @Environment(\.fullScreen) private var fullScreen

  let hide: Bool

  func body(content: Content) -> some View {
    content.onChange(of: hide, initial: true) {
      setToolbarVisible(!hide)
    }.onChange(of: fullScreen) {
      setToolbarVisible(!hide)
    }.onDisappear {
      setToolbarVisible(true)
    }
  }

  func setToolbarVisible(_ visible: Bool) {
    guard let window = capture.window else {
      return
    }

    window.setToolbarVisibility(visible)
  }
}

struct CursorHiddenViewModifier: ViewModifier {
  @State private var hidden = false

  let hide: Bool

  func body(content: Content) -> some View {
    content.onChange(of: hide, initial: true) {
      if hide {
        hideCursor()

        return
      }

      if hidden {
        unhideCursor()
      }
    }.onDisappear {
      if hidden {
        unhideCursor()
      }
    }
  }

  func hideCursor() {
    NSCursor.hide()

    hidden = true
  }

  func unhideCursor() {
    NSCursor.unhide()

    hidden = false
  }
}

extension View {
  func toolbarHidden(_ hidden: Bool) -> some View {
    self.modifier(ToolbarHiddenViewModifier(hide: hidden))
  }

  func cursorHidden(_ hidden: Bool) -> some View {
    self.modifier(CursorHiddenViewModifier(hide: hidden))
  }
}

struct ImageTransferable: Transferable {
  let url: URL
  let type: UTType
  let original: Bool

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image, shouldAttemptToOpenInPlace: true) { received in
      try .init(received: received, type: .image)
    }

    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      try .init(received: received, type: .folder)
    }
  }
}

extension URL {
  static let temporaryImagesDirectory = Self.temporaryDirectory.appending(components: Bundle.identifier, "Images")
}

extension ImageTransferable {
  init(received: ReceivedTransferredFile, type: UTType) throws {
    guard URL.cachesDirectory.contains(url: received.file) else {
      self.init(url: received.file, type: type, original: received.isOriginalFile)

      return
    }

    let destination = URL.temporaryImagesDirectory.appending(component: received.file.lastPathComponent)

    Logger.sandbox.info("Dropped image at URL \"\(received.file.string)\" is a promise; moving to \"\(destination.string)\"...")

    let manager = FileManager.default

    try manager.creatingDirectories(at: destination.deletingLastPathComponent(), code: .fileNoSuchFile) {
      try manager.moveItem(at: received.file, to: destination)
    }

    self.init(url: destination, type: type, original: false)
  }
}

extension NSPasteboard {
  func write(items: [some NSPasteboardWriting]) -> Bool {
    self.prepareForNewContents()

    return self.writeObjects(items)
  }
}

extension NSMenuItem {
  var isStandard: Bool {
    // This is not safe from evolution.
    !self.isSectionHeader && !self.isSeparatorItem
  }
}
