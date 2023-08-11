//
//  SequenceScene.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import SwiftUI

struct SequenceSelectionFocusedValueKey: FocusedValueKey {
  typealias Value = () -> [URL]
}

extension FocusedValues {
  var sequenceSelection: SequenceSelectionFocusedValueKey.Value? {
    get { self[SequenceSelectionFocusedValueKey.self] }
    set { self[SequenceSelectionFocusedValueKey.self] = newValue }
  }
}

struct SequenceScene: Scene {
  @FocusedValue(\.sequenceSelection) private var selection

  var body: some Scene {
    WindowGroup(for: Sequence.self) { $sequence in
      // When I use the initializer with the default value parameter, the result isn't persisted.
      if let sequence {
        // Idea: Add a feature that automatically removes borders embedded in images.
        SequenceView(sequence: sequence)
          .windowed()
      }
    }
    .windowToolbarStyle(.unifiedCompact) // Sexy!
    // TODO: Figure out how to remove the tab bar functionality (for this window group specifically).
    //
    // TODO: Figure out how to add a "Go to Current Image" button.
    //
    // Last time, I tried with a callback, but the ScrollViewProxy wouldn't scroll.
    .commands {
      SidebarCommands()

      CommandGroup(after: .newItem) {
        Divider()

        // I've thought about allowing the user to open the image(s) visible in the main view in Finder as well, but
        // it's not stable enough for me to consider. In addition, it's kind of weird visually, since there's no clear
        // selection (unlike the sidebar).
        Button("Show in Finder") {
          guard let urls = selection?(),
                !urls.isEmpty else {
            return
          }

          openFinder(for: urls)
        }.keyboardShortcut("R")
      }
    }
  }
}
