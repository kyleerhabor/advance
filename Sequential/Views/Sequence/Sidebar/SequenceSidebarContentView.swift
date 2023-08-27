//
//  SequenceSidebarContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/12/23.
//

import OSLog
import QuickLook
import SwiftUI

struct SequenceSidebarContentView: View {
  @Environment(\.fullScreen) private var fullScreen
  @State private var preview = [URL]()
  @State private var previewItem: URL?

  let sequence: Seq
  @Binding var selection: Set<SeqImage.ID>
  let scrollDetail: () -> Void

  var body: some View {
    let selection = Binding {
      self.selection
    } set: { selection in
      self.selection = selection

      scrollDetail()
    }

    // There's an uncomfortable amount of padding missing from the top when in full screen mode. If I try to add an
    // empty view when in full screen, toggling causes the images to go blank then immediately be restored, which looks
    // wack. I can't apply padding to the List, since it'll clip the contents, nor apply it to the ForEach / contents
    // since they'll all get it (which will create extra space when clicking, which is also why it can't just be applied
    // to the first child).
    List(selection: selection) {
      ForEach(sequence.images) { image in
        VStack {
          SequenceImageView(image: image)

          let path = image.url.lastPathComponent

          Text(path)
            .font(.subheadline)
            .padding(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(Color.secondaryFill)
            .clipShape(.rect(cornerRadius: 4))
            // TODO: Replace this for an expansion tooltip (like how NSTableView has it)
            //
            // I tried this before, but couldn't get sizing or the trailing ellipsis to work properly.
            .help(path)
        }
      }.onMove { source, destination in
        sequence.move(from: source, to: destination)
      }.dropDestination(for: URL.self) { urls, offset in
        Task {
          sequence.store(
            bookmarks: await sequence.insert(urls, scoped: false),
            at: offset
          )
        }
      }
    }
    .copyable(sequence.urls(from: self.selection))
    .quickLookPreview($previewItem, in: preview)
    .contextMenu { ids in
      Button("Show in Finder") {
        open(ids)
      }

      Button("Quick Look") {
        quicklook(ids)
      }

      Divider()

      let amount = ids.count

      if amount != 0 {
        Button(amount == 1 ? "Copy" : "Copy \(amount) Images", systemImage: "doc.on.doc") {
          let urls = sequence.urls(from: ids)
          
          if !NSPasteboard.general.write(items: urls as [NSURL]) {
            Logger.ui.error("Failed to write URLs to pasteboard: \(urls.map(\.string))")
          }
        }
      }
    } primaryAction: { ids in
      open(ids)
    }.focusedSceneValue(\.quicklook) {
      if previewItem == nil {
        quicklook(self.selection)
      } else {
        previewItem = nil
      }
    }
  }

  func open(_ ids: Set<SeqImage.ID>) {
    openFinder(selecting: sequence.urls(from: ids))
  }

  func quicklook(_ ids: Set<SeqImage.ID>) {
    preview = sequence.urls(from: ids)
    previewItem = preview.first
  }
}

#Preview {
  SequenceSidebarContentView(
    sequence: try! .init(urls: []),
    selection: .constant([]),
    scrollDetail: {}
  )
}
