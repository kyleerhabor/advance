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

extension FocusedValues {
  var sequenceSelection: SequenceSelectionFocusedValueKey.Value? {
    get { self[SequenceSelectionFocusedValueKey.self] }
    set { self[SequenceSelectionFocusedValueKey.self] = newValue }
  }
}

struct SequenceScene: Scene {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  // TODO: Use FocusedValue
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.appearance.rawValue) private var appearance: SettingsView.Scheme
  @FocusedValue(\.sequenceSelection) private var selection

  var body: some Scene {
    // Does Seq being an Observable cause trouble with the 
    WindowGroup(for: Seq.self) { $sequence in
      SequenceView(sequence: $sequence)
        .windowed()
    } defaultValue: {
      // You wouldn't believe how much work it took to get this parameter to behave correctly...
      .init(bookmarks: [])
    }
    .windowToolbarStyle(.unifiedCompact) // Sexy!
    // TODO: Figure out how to add a "Go to Current Image" button.
    //
    // I tried this prior with a callback, but ScrollViewProxy wouldn't scroll when called.
    //
    // FIXME: The "Enter/Exit Full Screen" option sometimes disappears.
    .commands {
      SidebarCommands()

      CommandGroup(after: .newItem) {
        // Is there a way to grab the default menu items used for a viewable-only document-based app? I'd rather not
        // hard-code values (specifically like this) that may change over time.
        Button("Open...") {
          let panel = NSOpenPanel()
          panel.canChooseFiles = true
          panel.allowsMultipleSelection = true
          panel.allowedContentTypes = [.image]

          // For some reason, the panel does not like being called in a Task (complains about not being run on the main
          // thread, even though it's worked before).
          panel.begin { res in
            guard res == .OK else {
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
        }.keyboardShortcut("o", modifiers: .command)

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
        .keyboardShortcut("R")
        .disabled(selection == nil || selection!.amount == 0)
      }

      CommandGroup(after: .windowArrangement) {
        // This little hack allows us to do stuff with the UI on startup (since it's always called).
        Color.clear
          .onAppear {
            delegate.onOpenURL = { sequence in
              openWindow(value: sequence)
            }
          }.onChange(of: appearance, initial: true) {
            // We need to set NSApp's appearance explicitly so windows we don't directly control (such as the about)
            // will still sync with the user's preference.
            NSApp.appearance = appearance?.app()
          }
      }
    }
  }
}
