//
//  SequenceScene.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import OSLog
import SwiftUI

struct SequenceSelection {
  let amount: Int
  let resolve: () -> [URL]
}

struct SequenceSelectionFocusedValueKey: FocusedValueKey {
  typealias Value = SequenceSelection
}

struct QuickLookFocusedValueKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var sequenceSelection: SequenceSelectionFocusedValueKey.Value? {
    get { self[SequenceSelectionFocusedValueKey.self] }
    set { self[SequenceSelectionFocusedValueKey.self] = newValue }
  }

  var quicklook: QuickLookFocusedValueKey.Value? {
    get { self[QuickLookFocusedValueKey.self] }
    set { self[QuickLookFocusedValueKey.self] = newValue }
  }
}

struct SequenceScene: Scene {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.openWindow) private var openWindow
  @AppStorage(Keys.appearance.key) private var appearance: SettingsView.Scheme
  @FocusedValue(\.quicklook) private var quicklook
  @FocusedValue(\.sequenceSelection) private var selection

  var body: some Scene {
    WindowGroup(for: Seq.self) { $sequence in
      SequenceView(sequence: $sequence)
        .windowed()
    } defaultValue: {
      // You wouldn't believe how much work it took to get this parameter to behave correctly.
      .init(bookmarks: [])
    }
    .windowToolbarStyle(.unifiedCompact) // Sexy!
    // TODO: Figure out how to add a "Go to Current Image" item.
    //
    // I tried this prior with a callback, but ScrollViewProxy wouldn't scroll when called.
    //
    // FIXME: The "Enter/Exit Full Screen" option sometimes disappears.
    .commands {
      SidebarCommands()

      let empty = selection == nil || selection!.amount == 0

      CommandGroup(after: .newItem) {
        Button("Open...", action: openFiles)
          .keyboardShortcut(.open)

        Divider()

        // I've thought about allowing the user to open the image(s) visible in the main view in Finder as well, but
        // it's not stable enough for me to consider. In addition, it's kind of weird visually, since there's no clear
        // selection (unlike the sidebar).
        Button("Show in Finder") {
          guard let urls = selection?.resolve(),
                !urls.isEmpty else {
            return
          }

          openFinder(for: urls)
        }
        .keyboardShortcut(.finder)
        .disabled(empty)

        Button("Quick Look") {
          quicklook?()
        }
        // For some reason, the shortcut is not aligned with the rest in the menu bar (though, I would rather it not
        // be displayed).
        //
        // For some reason, I can't bind the space key alone.
        .keyboardShortcut(.quicklook)
        .disabled(empty || quicklook == nil)
      }

      CommandGroup(after: .sidebar) {
//        Divider()
//
//        Button("Go to Current Image") {
//
//        }
//        .keyboardShortcut(.currentImage)
//        .disabled(empty)

        // The "Enter Full Screen" item is usually in its own space.
        Divider()
      }

      CommandGroup(after: .windowArrangement) {
        // This little hack allows us to do stuff with the UI on startup (since it's always called).
        Color.clear
          .onAppear {
            // We need to set NSApp's appearance explicitly so windows we don't directly control (such as the about)
            // will still sync with the user's preference.
            NSApp.appearance = appearance?.app()

            delegate.onOpenURL = { sequence in
              openWindow(value: sequence)
            }
          }
      }
    }
  }

  // Maybe a better name?
  func openFiles() {
    // Using .fileImporter(...) results in a crash, for some reason.
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image]

    Task {
      guard await panel.begin() == .OK else {
        return
      }

      do {
        let bookmarks = try panel.urls.map { url in
          try url.scoped { try url.bookmarkData() }
        }

        openWindow(value: Seq(bookmarks: bookmarks))
      } catch {
        Logger.ui.error("\(error)")
      }
    }
  }
}
