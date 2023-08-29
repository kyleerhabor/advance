//
//  SequenceScene.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import OSLog
import SwiftUI

struct SequenceSelection {
  let enabled: Bool
  let resolve: () -> [URL]
}

struct SequenceSelectionFocusedValueKey: FocusedValueKey {
  typealias Value = SequenceSelection
}

struct QuickLookFocusedValueKey: FocusedValueKey {
  typealias Value = () -> Void
}

struct SeqFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<Seq>
}

extension FocusedValues {
  var seq: SeqFocusedValueKey.Value? {
    get { self[SeqFocusedValueKey.self] }
    set { self[SeqFocusedValueKey.self] = newValue }
  }

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
  @EnvironmentObject private var delegate: AppDelegate
  @Environment(\.openWindow) private var openWindow
  @AppStorage(Keys.appearance.key) private var appearance: SettingsView.Scheme
  @FocusedValue(\.quicklook) private var quicklook
  @FocusedValue(\.seq) private var sequence
  @FocusedValue(\.sequenceSelection) private var selection

  var body: some Scene {
    WindowGroup(for: Seq.self) { $sequence in
      // FIXME: There is a noticeable delay in clicking UI elements when there are a lot of (large) images on screen.
      //
      // This seems to not be unique to Sequential, given I've experienced it in Finder as well.
      SequenceView(sequence: $sequence)
        .focusedSceneValue(\.seq, $sequence)
        .windowed()
    } defaultValue: {
      try! .init(urls: [])
    }
    .windowToolbarStyle(.unifiedCompact)
    // FIXME: The "Enter/Exit Full Screen" option sometimes disappears.
    .commands {
      SidebarCommands()

      InspectorCommands()

      let enabled = selection?.enabled == true

      CommandGroup(after: .newItem) {
        Button("Open...", action: openFiles)
          .keyboardShortcut(.open)

        Divider()

        Button("Show in Finder") {
          guard let urls = selection?.resolve(),
                !urls.isEmpty else {
            return
          }

          openFinder(selecting: urls)
        }
        .keyboardShortcut(.finder)
        .disabled(!enabled)

        Button("Quick Look") {
          quicklook?()
        }
        // For some reason, I can't bind the space key alone. When I use Command-Space, the shortcut is also not
        // aligned with the rest in the menu bar.
        .keyboardShortcut(.quicklook)
        .disabled(!enabled || quicklook == nil)
      }

      CommandGroup(after: .sidebar) {
        // The "Enter Full Screen" item is usually in its own space.
        Divider()
      }

      CommandGroup(after: .windowArrangement) {
        // This little hack allows us to do stuff with the UI on startup (since it's always called).
        Color.clear.onAppear {
          // We need to set NSApp's appearance explicitly so windows we don't directly control (such as the about) will
          // still sync with the user's preference.
          //
          // Note that we can't use .onChange(of:initial:_) since this scene will have to be focused to receive the
          // change (when the settings view would have focus).
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
        let seq = try Seq(urls: panel.urls)

        // We could really do better than this...
        if let sequence, sequence.bookmarks.isEmpty == true {
          seq.bookmarks = await seq.load()
          seq.update()

          sequence.wrappedValue = seq
        } else {
          // TODO: Fill in the existing window when there are no bookmarks.
          openWindow(value: seq)
        }
      } catch {
        Logger.ui.error("\(error)")
      }
    }
  }
}
