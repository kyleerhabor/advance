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
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.seqSelection) private var selection
  @Environment(\.seqInspection) private var inspection
  @State private var preview = [URL]()
  @State private var previewItem: URL?
  @State private var error: String?

  let sequence: Seq
  let scrollDetail: () -> Void

  var body: some View {
    let selection = Binding {
      self.selection.wrappedValue
    } set: { selection in
      self.selection.wrappedValue = selection
      self.inspection.wrappedValue = selection

      // FIXME: Scrolling re-evaluates the SwiftUI view hierarchy in SequenceDetailView.
      scrollDetail()
    }
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
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
    .copyable(sequence.urls(from: self.selection.wrappedValue))
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

      Button(amount == 1 ? "Copy" : "Copy \(amount) Images", systemImage: "doc.on.doc") {
        let urls = sequence.urls(from: ids)

        if !NSPasteboard.general.write(items: urls as [NSURL]) {
          Logger.ui.error("Failed to write URLs to pasteboard: \(urls.map(\.string))")
        }
      }

      let resolved = copyDepot.resolved

      if !resolved.isEmpty {
        SequenceCopyDestinationView(destinations: resolved) { destination in
          let urls = sequence.urls(from: ids)

          do {
            // Oh god.
            try destination.scoped {
              try urls.forEach { url in
                try url.scoped {
                  do {
                    // I doubt this batch file copying could be atomic.
                    try FileManager.default.copyItem(at: url, to: destination.appending(component: url.lastPathComponent))
                  } catch {
                    guard let err = error as? CocoaError, err.code == .fileWriteFileExists else {
                      throw error
                    }

                    self.error = error.localizedDescription

                    throw ExecutionError.interrupt
                  }
                }
              }
            }
          } catch {
            if let err = error as? ExecutionError, err == .interrupt {
              return
            }

            Logger.ui.error("Failed to copy all images in \(urls.map(\.string)) to destination \"\(destination.string)\": \(error)")
          }
        }
      }

      Divider()

      SequenceInfoButtonView(ids: ids)
    }
    .alert(self.error ?? "", isPresented: error) {}
    .focusedSceneValue(\.quicklook) {
      if previewItem == nil {
        quicklook(self.selection.wrappedValue)
      } else {
        previewItem = nil
      }
    }.onAppear {
      copyDepot.resolve()
    }
  }

  func open(_ ids: SequenceView.Selection) {
    openFinder(selecting: sequence.urls(from: ids))
  }

  func quicklook(_ ids: SequenceView.Selection) {
    preview = sequence.urls(from: ids)
    previewItem = preview.first
  }
}

#Preview {
  SequenceSidebarContentView(
    sequence: try! .init(urls: []),
    scrollDetail: {}
  )
}
