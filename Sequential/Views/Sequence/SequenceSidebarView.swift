//
//  SequenceSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import CoreTransferable
import SwiftUI

struct SequenceSidebarView: View {
  @State private var preview = [URL]()
  @State private var previewItem: URL?

  @Binding var selection: Set<URL>
  let images: [SequenceImage]
  let onMove: (IndexSet, Int) -> Void
  let onDrop: ([URL], Int) -> Void
  let onDelete: () -> Void

  var body: some View {
    // There's an uncomfortable amount of padding missing from the top when in full screen mode.
    List(selection: $selection) {
      ForEach(images, id: \.url) { image in
        VStack {
          SequenceImageView(image: image)

          let path = image.url.lastPathComponent

          Text(path)
            .font(.subheadline)
            .padding(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(Color.secondaryFill)
            .clipShape(.rect(cornerRadius: 4))
            .help(path)
        }
      }
      .onMove(perform: onMove)
      .dropDestination(for: URL.self, action: onDrop)
    }
    .quickLookPreview($previewItem, in: preview)
    .contextMenu { urls in
      Button("Show in Finder") {
        openFinder(for: Array(urls))
      }

      // TODO: Figure out how to bind this to the space key while the context menu is not open.
      //
      // I tried using .onKeyPress(_:action:) on the list, but the action was never called. Maybe related to 109799056?
      // "View.onKeyPress(_:action:) can't filter key presses when bridged controls have focus."
      Button("Quick Look") {
        quicklook(urls: urls)
      }
    } primaryAction: { urls in
      openFinder(for: Array(urls))
    }
    // onDelete(perform:) doesn't seem to work.
    .onDeleteCommand(perform: onDelete)
    .focusedSceneValue(\.sequenceSelection, .init(
      amount: selection.count,
      resolve: { ordered(urls: selection) }
    ))
  }

  func ordered(urls: Set<URL>) -> [URL] {
    let images = images
      .enumerated()
      .reduce(into: [:]) { partialResult, pair in
        partialResult[pair.1.url] = pair.0
      }

    return urls.sorted { a, b in
      guard let ai = images[a] else {
        return false
      }

      guard let bi = images[b] else {
        return true
      }

      return ai < bi
    }
  }

  func quicklook(urls: Set<URL>) {
    preview = ordered(urls: urls)
    previewItem = preview.first
  }
}
