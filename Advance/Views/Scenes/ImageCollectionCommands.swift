//
//  ImageCollectionCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/18/23.
//

import Defaults
import SwiftUI

// MARK: - Views

struct ImageCollectionCommands: Commands {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(CopyDepot.self) private var depot
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.windowSizeReset) private var windowSizeReset
  @FocusedValue(\.open) private var open
  @FocusedValue(\.finderShow) private var showFinder
  @FocusedValue(\.finderOpen) private var openFinder
  @FocusedValue(\.quicklook) private var quicklook
  @FocusedValue(\.sidebarSearch) private var sidebarSearch
  @FocusedValue(\.currentImageShow) private var currentImageShow
  @FocusedValue(\.bookmark) private var bookmark
  @FocusedValue(\.back) private var back
  @FocusedValue(\.backAll) private var backAll
  @FocusedValue(\.forward) private var forward
  @FocusedValue(\.forwardAll) private var forwardAll
  @FocusedValue(\.liveTextIcon) private var liveTextIcon
  @FocusedValue(\.liveTextHighlight) private var liveTextHighlight
  
  var body: some Commands {
    // TODO: Figure out how to remove the "Show/Hide Toolbar" item.
    ToolbarCommands()

    SidebarCommands()

    CommandGroup(after: .newItem) {
      MenuItemButton(item: open ?? .init(identity: nil, enabled: true) {
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
      }) {
        Text("Open.Interactive")
      }.keyboardShortcut(.open)
    }

    CommandGroup(after: .saveItem) {
      Section {
        MenuItemButton(item: showFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Show")
        }.keyboardShortcut(.showFinder)

        MenuItemToggle(toggle: quicklook ?? .init(identity: [], enabled: false, state: false, action: noop)) {
          Text("Quick Look")
        }.keyboardShortcut(.quicklook)
      }

      Section {
        MenuItemButton(item: openFinder ?? .init(identity: [], enabled: false, action: noop)) {
          Text("Finder.Open")
        }.keyboardShortcut(.openFinder)
      }
    }

    CommandGroup(after: .textEditing) {
      MenuItemButton(item: sidebarSearch ?? .init(identity: nil, enabled: false, action: noop)) {
        Text("Search.Interaction")
      }.keyboardShortcut(.searchSidebar)
    }

    CommandGroup(after: .sidebar) {
      // The "Enter Full Screen" item is usually in its own space.
      Divider()
    }

    CommandMenu("Images.Command.Section.Image") {
      Section {
        MenuItemButton(item: currentImageShow ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Sidebar.Item.Show")
        }.keyboardShortcut(.showCurrentImage)
      }

      Section {
        MenuItemToggle(toggle: bookmark ?? .init(identity: nil, enabled: false, state: false, action: noop)) { $isOn in
          ImageCollectionBookmarkView(showing: $isOn)
        }.keyboardShortcut(.bookmark)
      }

      Section("Images.Command.Section.LiveText") {
        MenuItemButton(item: liveTextIcon?.item ?? .init(identity: nil, enabled: false, action: noop)) {
          Text(liveTextIcon?.state == true ? "Images.Command.LiveText.Icon.Hide" : "Images.Command.LiveText.Icon.Show")
        }.keyboardShortcut(.liveTextIcon)

        MenuItemButton(item: liveTextHighlight?.item ?? .init(identity: [], enabled: false, action: noop)) {
          Text(liveTextHighlight?.state == true ? "Images.Command.LiveText.Highlight.Hide" : "Images.Command.LiveText.Highlight.Show")
        }.keyboardShortcut(.liveTextHighlight)
      }

      Section {
        MenuItemButton(item: back ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Back")
        }.keyboardShortcut(.back)

        MenuItemButton(item: backAll ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Back.All")
        }.keyboardShortcut(.backAll)

        MenuItemButton(item: forward ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Forward")
        }.keyboardShortcut(.forward)

        MenuItemButton(item: forwardAll ?? .init(identity: nil, enabled: false, action: noop)) {
          Text("Images.Command.Navigation.Forward.All")
        }.keyboardShortcut(.forwardAll)
      }
    }

    CommandGroup(after: .windowSize) {
      MenuItemButton(item: windowSizeReset ?? .init(identity: nil, enabled: false, action: noop)) {
        Text("Images.Command.Window.Size.Reset")
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
    //
    // FIXME: For some reason, entering Command-Shit-. to show hidden files causes the service to crash.
    //
    // This only happens when using identifier. Interestingly, it happens in SwiftUI, too.
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
