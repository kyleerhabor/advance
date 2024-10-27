//
//  ImagesCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.liveTextIcon) private var liveTextIcon
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.finderShow) private var finderShow
  @FocusedValue(\.finderOpen) private var finderOpen
  @FocusedValue(\.imagesSidebarShow) private var sidebarShow
  @FocusedValue(\.imagesLiveTextIcon) private var imagesLiveTextIcon
  @FocusedValue(\.imagesLiveTextHighlight) private var liveTextHighlight
  @FocusedValue(\.windowOpen) private var windowOpen
  @FocusedValue(\.imagesWindowResetSize) private var windowResetSize

  var body: some Commands {
    SidebarCommands()
    ToolbarCommands()

    CommandGroup(after: .newItem) {
      Section {
        MenuItemButton(item: windowOpen ?? AppMenuActionItem(identity: nil, enabled: true, action: open)) {
          Text("Images.Commands.File.Open")
        }
        .keyboardShortcut(.windowOpen)
      }
    }

    CommandGroup(after: .saveItem) {
      Section {
        MenuItemButton(item: finderShow ?? AppMenuActionItem(identity: .unknown, enabled: false, action: noop)) {
          Text("Finder.Item.Show")
        }
        .keyboardShortcut(.finderShowItem)

        MenuItemButton(item: finderOpen ?? AppMenuActionItem(identity: [], enabled: false, action: noop)) {
          Text("Finder.Item.Open")
        }
        .keyboardShortcut(.finderOpenItem)
      }
    }

    CommandMenu("Images.Commands.Image") {
      MenuItemButton(item: sidebarShow ?? AppMenuActionItem(identity: nil, enabled: false, action: noop)) {
        Text("Sidebar.Item.Show")
      }
      .keyboardShortcut(.sidebarShowItem)

      Section("Images.Commands.Image.LiveText") {
        MenuItemToggle(toggle: imagesLiveTextIcon ?? AppMenuToggleItem(identity: nil, enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Commands.Image.LiveText.Icon.Hide" : "Images.Commands.Image.LiveText.Icon.Show") {
            isOn.toggle()
          }
        }
        .keyboardShortcut(.liveTextIcon)

        MenuItemToggle(toggle: liveTextHighlight ?? AppMenuToggleItem(identity: [], enabled: false, state: false, action: noop)) { $isOn in
          Button(isOn ? "Images.Commands.Image.LiveText.Highlight.Hide" : "Images.Commands.Image.LiveText.Highlight.Show") {
            isOn.toggle()
          }
        }
        .keyboardShortcut(.liveTextHighlight)
      }
    }

    CommandGroup(after: .windowSize) {
      MenuItemButton(item: windowResetSize ?? AppMenuActionItem(identity: nil, enabled: false, action: noop)) {
        Text("Images.Commands.Window.ResetSize")
      }
      .keyboardShortcut(.windowResetSize)
    }
  }

  private nonisolated static func source(
    urls: [URL],
    options: FileManager.DirectoryEnumerationOptions
  ) async -> [Source<[URL]>] {
    urls.compactMap { url in
      do {
        return try ImagesModel.source(url: url, options: options)
      } catch {
        Logger.model.error("Could not source URL \"\(url.pathString)\" with options \"\(options.rawValue)\" for open command: \(error)")

        return nil
      }
    }
  }

  func open() {
    Task {
      await open()
    }
  }

  func open() async {
    let panel = NSOpenPanel()
    panel.identifier = .imagesWindowOpen
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = imagesContentTypes

    // We don't want panel.begin() since it creates a modeless window—a kind which SwiftUI does not recognize focus for.
    // This is most apparent when the open dialog window is the only window and the user activates the app, causing
    // SwiftUI to create a new window.
    //
    // FIXME: Entering Command-Shift-. to show hidden files causes the service to crash.
    //
    // This only occurs when using an identifier. Interestingly, this affects SwiftUI, too (using fileDialogCustomizationID(_:)).
    guard panel.runModal() == .OK else {
      return
    }

    let images = ImagesModel(id: UUID())
    let options = FileManager.DirectoryEnumerationOptions(
      excludeHiddenFiles: !importHiddenFiles,
      excludeSubdirectoryFiles: !importSubdirectories
    )

    do {
      try await images.submit(items: Self.source(urls: panel.urls, options: options))
    } catch {
      Logger.model.error("\(error)")

      return
    }

    openWindow(value: images)
  }
}
