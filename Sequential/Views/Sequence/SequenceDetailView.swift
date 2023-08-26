//
//  SequenceDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import OSLog
import SwiftUI

struct SequenceDetailItemView: View {
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value
  @FocusedValue(\.scrollSidebar) private var scrollSidebar
  @State private var error: String?

  let image: SeqImage
  @Binding var selection: Set<SeqImage.ID>
  let liveText: Bool
  @Binding var liveTextIcon: Bool
  @Binding var highlight: Bool
  let folders: [URL]

  var body: some View {
    let url = image.url
    let margin = Double(margins)
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
    }
    .listRowInsets(.listRow + .init(margin * 6))
    .listRowSeparator(.hidden)
    .shadow(radius: margin)
    .contextMenu {
      Button("Show in Finder") {
        openFinder(for: url)
      }

      Button("Show in Sidebar", systemImage: "sidebar.squares.left") {
        selection = [image.id]
        scrollSidebar?()
      }

      Divider()

      Button("Copy", systemImage: "doc.on.doc") {
        if !NSPasteboard.general.write(items: [url as NSURL]) {
          Logger.ui.error("Failed to write URL \"\(url.string)\" to pasteboard")
        }
      }

      if !folders.isEmpty {
        Menu("Copy to Folder") {
          ForEach(folders, id: \.self) { folder in
            Button(folder.lastPathComponent) {
              do {
                try folder.scoped {
                  do {
                    try FileManager.default.copyItem(at: url, to: folder.appending(component: url.lastPathComponent))
                  } catch {
                    guard let err = error as? CocoaError,
                          err.code == .fileWriteFileExists else {
                      throw error
                    }

                    self.error = error.localizedDescription
                  }
                }
              } catch {
                Logger.ui.info("Failed to copy image at \"\(url.string)\" to destination \"\(folder.string)\": \(error)")
              }
            }
          }
        }
      }
    }.alert(self.error ?? "", isPresented: error) {}
  }
}

struct SequenceDetailView: View {
  @Environment(Depot.self) private var depot
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var appLiveTextIcon = Keys.liveTextIcon.value
  @SceneStorage(Keys.liveTextIcon.key) private var liveTextIcon: Bool?
  @FocusedValue(\.scrollSidebar) private var scrollSidebar
  @State private var highlight = false

  let images: [SeqImage]
  @Binding var selection: Set<SeqImage.ID>

  var body: some View {
    let folders = depot.destinations.compactMap(\.url)
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
    // Ironically, the ring goes away when Live Text is enabled.
    //
    // I played around with adding a list item whose sole purpose was to capture the scrolling state, but couldn't get
    // it to not take up space and mess with the ForEach items. I also tried applying it only to the first element, but
    // it would just go out of view and stop reporting changes. I'll likely just need to reimplement NSTableView or
    // NSCollectionView.
    List(images) { image in
      SequenceDetailItemView(
        image: image,
        selection: $selection,
        liveText: liveText,
        liveTextIcon: liveTextIcon,
        highlight: $highlight,
        folders: folders
      )
    }
    .listStyle(.plain)
    .toolbar {
      if liveText {
        Toggle("Show Live Text icons", systemImage: "text.viewfinder", isOn: liveTextIcon)
      }
    }
    // Since the toolbar disappears in full screen mode, we can't use .keyboardShortcut(_:modifiers:).
    .onKey("t", modifiers: [.command], repeating: true) {
      liveTextIcon.wrappedValue.toggle()
    }.onKey("t", modifiers: [.command, .shift]) {
      highlight.toggle()
    }.onAppear {
      depot.resolve()
    }
  }
}

#Preview {
  SequenceDetailView(
    images: [],
    selection: .constant([])
  )
}
