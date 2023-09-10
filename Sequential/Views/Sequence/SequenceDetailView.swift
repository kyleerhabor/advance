//
//  SequenceDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import Combine
import OSLog
import SwiftUI

struct SequenceDetailItemView: View {
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @State private var error: String?

  let image: SeqImage
  var liveTextIcon: Bool
  @Binding var highlight: Bool
  let copyDestinations: [CopyDepotURL]
  let scroll: (SeqImage.ID) -> Void

  var body: some View {
    let url = image.url
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    SequenceImageView(image: image) { image in
      image.resizable().overlay {
        if liveText {
          LiveTextView(url: url, highlight: $highlight)
            .supplementaryInterfaceHidden(!liveTextIcon)
        }
      }
    }.contextMenu {
      Button("Show in Finder") {
        openFinder(selecting: url)
      }

      Button("Show in Sidebar", systemImage: "sidebar.squares.left") {
        scroll(image.id)
      }

      Divider()

      Button("Copy", systemImage: "doc.on.doc") {
        if !NSPasteboard.general.write(items: [url as NSURL]) {
          Logger.ui.error("Failed to write URL \"\(url.string)\" to pasteboard")
        }
      }

      if !copyDestinations.isEmpty {
        SequenceCopyDestinationView(destinations: copyDestinations) { destination in
          do {
            try destination.scoped {
              do {
                try FileManager.default.copyItem(at: url, to: destination.appending(component: url.lastPathComponent))
              } catch {
                guard let err = error as? CocoaError,
                      err.code == .fileWriteFileExists else {
                  throw error
                }

                self.error = error.localizedDescription
              }
            }
          } catch {
            Logger.ui.info("Failed to copy image at \"\(url.string)\" to destination \"\(destination.string)\": \(error)")
          }
        }
      }

      Divider()

      SequenceInfoButtonView(ids: [image.id])
    }.alert(self.error ?? "", isPresented: error) {}
  }
}

struct SequenceDetailContentView: View {
  @Environment(\.seqSelection) private var selection

  let image: SeqImage
  let liveTextIcon: Bool
  @Binding var highlight: Bool
  let copyDestinations: [CopyDepotURL]
  let scrollSidebar: () -> Void

  var body: some View {
    SequenceDetailItemView(
      image: image,
      liveTextIcon: liveTextIcon,
      highlight: $highlight,
      copyDestinations: copyDestinations
    ) { id in
      selection.wrappedValue = [id]
      scrollSidebar()
    }
  }
}

struct SequenceDetailView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.seqSelection) private var selection
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var appLiveTextIcon = Keys.liveTextIcon.value
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value
  @AppStorage(Keys.collapseMargins.key) private var collapse = Keys.collapseMargins.value
  @SceneStorage(Keys.liveTextIcon.key) private var liveTextIcon: Bool?
  @State private var highlight = false

  let images: [SeqImage]
  let scrollSidebar: () -> Void

  var body: some View {
    let liveTextIcon = Binding {
      self.liveTextIcon ?? appLiveTextIcon
    } set: { icons in
      self.liveTextIcon = icons
    }

    // A killer limitation in using List is it doesn't support magnification, like how an NSScrollView does. Maybe try
    // reimplementing an NSCollectionView / NSTableView again? I tried implementing a MagnifyGesture solution but ran
    // into the following issues:
    // - The list, itself, was zoomed out, and not the cells. This made views that should've been visible not appear
    // unless explicitly scrolling down the new list size.
    // - When setting the scale factor on the cells, they would maintain their frame size, creating varying gaps
    // between each other
    // - At a certain magnification level (somewhere past `x < 0.25` and `x > 4`), the app may have crashed.
    //
    // This is not even commenting on how it's not a one-to-one equivalent to the native experience of magnifying.
    //
    // For reference, I tried implementing a simplified version of https://github.com/fuzzzlove/swiftui-image-viewer
    //
    // TODO: Figure out how to remove that annoying ring when right clicking on an image.
    //
    // Ironically, the ring goes away for most of the frame when Live Text is enabled.
    //
    // I played around with adding a list item whose sole purpose was to capture the scrolling state, but couldn't get
    // it to not take up space and mess with the ForEach items. I also tried applying it only to the first element, but
    // it would just go out of view and stop reporting changes. I'll likely just need to reimplement NSTableView or
    // NSCollectionView.
    //
    // FIXME: Leaving Sequential, switching back, and immediately trying to scroll may result in unstable positioning.
    List {
      let margin = Double(margins)

      Group {
        let half = margin * 3
        let full = half * 2
        let inset = EdgeInsets(full)
        let top = EdgeInsets(horizontal: full, top: full, bottom: half)
        let between = EdgeInsets(horizontal: full, top: half, bottom: half)
        let bottom = EdgeInsets(horizontal: full, top: half, bottom: full)

        let mid = images.dropFirst().dropLast()

        if let begin = images.first {
          SequenceDetailContentView(
            image: begin,
            liveTextIcon: liveTextIcon.wrappedValue,
            highlight: $highlight,
            copyDestinations: copyDepot.resolved,
            scrollSidebar: scrollSidebar
          ).listRowInsets(.listRow + (collapse ? top : inset))
        }

        ForEach(mid) { image in
          SequenceDetailContentView(
            image: image,
            liveTextIcon: liveTextIcon.wrappedValue,
            highlight: $highlight,
            copyDestinations: copyDepot.resolved,
            scrollSidebar: scrollSidebar
          ).listRowInsets(.listRow + (collapse ? between : inset))
        }

        if let end = images.last {
          SequenceDetailContentView(
            image: end,
            liveTextIcon: liveTextIcon.wrappedValue,
            highlight: $highlight,
            copyDestinations: copyDepot.resolved,
            scrollSidebar: scrollSidebar
          ).listRowInsets(.listRow + (collapse ? bottom : inset))
        }
      }
      .listRowSeparator(.hidden)
      .shadow(radius: margin)
    }
    .listStyle(.plain)
    .toolbar {
      if liveText && !images.isEmpty {
        Toggle("Show Live Text icons", systemImage: "text.viewfinder", isOn: liveTextIcon)
      }
    }
    // Since the toolbar disappears in full screen mode, we can't use .keyboardShortcut(_:modifiers:). However, we'll
    // need to fix the implementation so it's part of the responder chain.
    .onKey("t", modifiers: [.command], repeating: true) {
      liveTextIcon.wrappedValue.toggle()
    }.onKey("t", modifiers: [.command, .shift]) {
      highlight.toggle()
    }.onAppear {
      copyDepot.resolve()
    }
  }
}

#Preview {
  SequenceDetailView(
    images: [],
    scrollSidebar: {}
  )
}
