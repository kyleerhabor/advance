//
//  ImageCollectionCommands.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/18/23.
//

import Defaults
import OSLog
import SwiftUI

// MARK: - Focused value keys

enum AppMenuOpen: Equatable {
  case window
}

struct AppMenuOpenFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenu<AppMenuOpen>
}

struct AppMenuQuickLookFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggle<[URL]>
}

struct AppMenuBookmarkedFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<Bool>
}

struct AppMenuJumpToCurrentImageFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenu<ImageCollectionItemImage.ID>
}

extension FocusedValues {
  var openFileImporter: AppMenuOpenFocusedValueKey.Value? {
    get { self[AppMenuOpenFocusedValueKey.self] }
    set { self[AppMenuOpenFocusedValueKey.self] = newValue }
  }

  var sidebarQuicklook: AppMenuQuickLookFocusedValueKey.Value? {
    get { self[AppMenuQuickLookFocusedValueKey.self] }
    set { self[AppMenuQuickLookFocusedValueKey.self] = newValue }
  }

  var jumpToCurrentImage: AppMenuJumpToCurrentImageFocusedValueKey.Value? {
    get { self[AppMenuJumpToCurrentImageFocusedValueKey.self] }
    set { self[AppMenuJumpToCurrentImageFocusedValueKey.self] = newValue }
  }
}

// MARK: - Views

struct ImageCollectionCommands: Commands {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(CopyDepot.self) private var depot
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.window) private var win
  @FocusedValue(\.back) private var back
  @FocusedValue(\.forward) private var forward
  @FocusedValue(\.openFileImporter) private var openFileImporter
  @FocusedValue(\.showFinder) private var showFinder
  @FocusedValue(\.openFinder) private var openFinder
  @FocusedValue(\.sidebarQuicklook) private var quicklook
  @FocusedValue(\.jumpToCurrentImage) private var jumpToCurrentImage
  @FocusedValue(\.searchSidebar) private var searchSidebar
  @FocusedValue(\.liveTextIcon) private var liveTextIcon
  @FocusedValue(\.liveTextHighlight) private var liveTextHighlight
  private var window: NSWindow? { win?.window }
  
  var body: some Commands {
    // TODO: Figure out how to remove the "Show/Hide Toolbar" item.
    ToolbarCommands()

    SidebarCommands()

    CommandGroup(after: .newItem) {
      Button("Open...") {
        if let openFileImporter {
          openFileImporter.action()

          return
        }

        let urls = Self.performImageFilePicker()

        guard !urls.isEmpty else {
          return
        }

        Task {
          let collection = await resolve(urls: urls, in: .init())
          let id = UUID()

          manager.collections[id] = collection

          openWindow(value: id)
        }
      }.keyboardShortcut(.open)
    }

    CommandGroup(after: .saveItem) {
      Section {
        MenuItemButton(item: showFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Show")
        }.keyboardShortcut(.showFinder)

        Button("Quick Look") {
          quicklook?.menu.action()
        }
        .keyboardShortcut(.quicklook)
        .disabled(quicklook?.enabled != true)
      }

      Section {
        MenuItemButton(item: openFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Open")
        }.keyboardShortcut(.openFinder)
      }
    }

    CommandGroup(after: .textEditing) {
      Button("Search.Interaction") {
        searchSidebar?.action()
      }.keyboardShortcut(.searchSidebar)
    }

    CommandGroup(after: .sidebar) {
      // The "Enter Full Screen" item is usually in its own space.
      Divider()
    }

    CommandMenu("Command.Section.Image") {
      Button("Command.Image.Sidebar") {
        jumpToCurrentImage?.action()
      }
      .keyboardShortcut(.jumpToCurrentImage)
      .disabled(jumpToCurrentImage == nil)

      Section("Command.Section.LiveText") {
        Button(liveTextIcon?.state == true ? "Command.LiveText.Icon.Hide" : "Command.LiveText.Icon.Show") {
          liveTextIcon?.menu.action()
        }
        .disabled(liveTextIcon?.enabled != true)
        .keyboardShortcut(.liveTextIcon)

        Button(liveTextHighlight?.state == true ? "Command.LiveText.Highlight.Hide" : "Command.LiveText.Highlight.Show") {
          liveTextHighlight?.menu.action()
        }
        .disabled(liveTextHighlight?.enabled != true)
        .keyboardShortcut(.liveTextHighlight)
      }

      Section {
        MenuItemButton(item: back ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Back")
        }.keyboardShortcut(.back)

        MenuItemButton(item: forward ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Forward")
        }.keyboardShortcut(.forward)
      }
    }

    CommandGroup(after: .windowSize) {
      Button("Command.Window.Size.Reset") {
        window?.setContentSize(ImageCollectionScene.defaultSize)
      }.keyboardShortcut(.resetWindowSize)
    }

    CommandGroup(after: .windowArrangement) {
      // This little hack allows us to do stuff with the UI on startup (since it's always called).
      Color.clear.onAppear {
        delegate.onOpen = { urls in
          Task {
            let collection = await resolve(urls: urls, in: .init())
            let id = UUID()

            manager.collections[id] = collection

            openWindow(value: id)
          }
        }
      }
    }
  }

  static func performImageFilePicker() -> [URL] {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image]
    panel.identifier = .init(FileDialogOpenViewModifier.id)

    // We don't want panel.begin() since it creating a modeless window causes SwiftUI to not treat it like a window.
    // This is most obvious when there are no windows but the open dialog and the app is activated, creating a new
    // window for the scene.
    guard panel.runModal() == .OK else {
      return []
    }

    return panel.urls
  }

  static func saving(
    images: [ImageCollectionItemImage],
    to destination: URL,
    _ body: (URL) throws -> Void
  ) throws -> Void {
    try ImageCollectionCopyingView.saving {
      try destination.withSecurityScope {
        try images.forEach { image in
          try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
            try image.withSecurityScope {
              try body(url)
            }
          }
        }
      }
    }
  }

  func prepare(url: URL) -> ImageCollection.Kind {
    let source = URLSource(url: url, options: [.withReadOnlySecurityScope, .withoutImplicitSecurityScope])

    if url.isDirectory() {
      return .document(.init(
        source: source,
        files: url.withSecurityScope {
          FileManager.default
            .contents(at: url, options: .init(includingHiddenFiles: importHidden, includingSubdirectories: importSubdirectories))
            .finderSort()
            .map { .init(url: $0, options: .withoutImplicitSecurityScope) }
        }
      ))
    }

    return .file(source)
  }

  static func resolve(kinds: [ImageCollection.Kind], in store: BookmarkStore) async -> ImageCollection {
    let state = await ImageCollection.resolve(kinds: kinds, in: store)
    let order = kinds.flatMap { kind in
      kind.files.compactMap { source in
        state.value[source.url]?.bookmark
      }
    }

    let items = Dictionary(uniqueKeysWithValues: state.value.map { pair in
      (pair.value.bookmark, ImageCollectionItem(root: pair.value, image: nil))
    })

    let collection = ImageCollection(
      store: state.store,
      items: items,
      order: .init(order)
    )

    return collection
  }

  // MARK: - Convenience (concurrency)

  func resolve(urls: [URL], in store: BookmarkStore) async -> ImageCollection {
    let kinds = urls.map(prepare(url:))

    return await Self.resolve(kinds: kinds, in: store)
  }
}
