//
//  ImageCollectionDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import OSLog
import SwiftUI

struct ImageCollectionDetailItemBookmarkView: View {
  @Environment(\.collection) @Binding private var collection

  let image: ImageCollectionItem

  var body: some View {
    let bookmarked = image.bookmark.bookmarked

    Button {
      image.bookmark.bookmarked = !bookmarked
      collection.updateBookmarks()
    } label: {
      Label(bookmarked ? "Remove Bookmark" : "Bookmark", systemImage: "bookmark")
    }
  }
}

struct ImageCollectionDetailItemView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.collapseMargins.key) private var collapse = Keys.collapseMargins.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @State private var error: String?

  let image: ImageCollectionItem
  let margin: Double
  let insets: EdgeInsets
  var liveTextIcon: Bool
  let scrollSidebar: () -> Void

  var body: some View {
    let url = image.url
    let insets = collapse
      ? insets
      : .init(margin * 6)
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    ImageCollectionItemView(image: image) { image in
      image.resizable().overlay {
        if liveText {
          @Bindable var image = self.image

          // I tried using a (CG/NS)Image instead of a URL, but that lead to a memory leak.
          LiveTextView(
            url: image.url,
            orientation: image.orientation,
            analysis: $image.analysis
          ).supplementaryInterfaceHidden(!liveTextIcon)
        }
      }
    }
    .shadow(radius: margin)
    .listRowInsets(.listRow + insets)
    .contextMenu {
      Button("Show in Finder") {
        openFinder(selecting: url)
      }

      Button("Show in Sidebar", systemImage: "sidebar.squares.leading") {
        selection = [image.id]
        scrollSidebar()
      }

      Divider()

      Button("Copy", systemImage: "doc.on.doc") {
        if !NSPasteboard.general.write(items: [url as NSURL]) {
          Logger.ui.error("Failed to write URL \"\(url.string)\" to pasteboard")
        }
      }

      if !copyDepot.resolved.isEmpty {
        ImageCollectionCopyFolderView(error: $error) { [url] }
      }

      // TODO: Implement "Copy to Folder"

      Divider()

      ImageCollectionDetailItemBookmarkView(image: image)

      Divider()

      Button("Get Info", systemImage: "info.circle") {
        // TODO: Implement.
      }
    }.alert(self.error ?? "", isPresented: error) {}
  }
}

struct ImageCollectionDetailView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var appLiveTextIcon = Keys.liveTextIcon.value
  @SceneStorage(Keys.liveTextIcon.key) private var liveTextIcon: Bool?
  @State private var showingDetails = false

  let images: [ImageCollectionItem]
  let scrollSidebar: () -> Void
  var icon: Bool {
    liveTextIcon ?? appLiveTextIcon
  }

  var body: some View {
    let margin = Double(margins)
    let half = margin * 3
    let full = half * 2

    List {
      Group {
        let top = EdgeInsets(horizontal: full, top: full, bottom: half)
        let middle = EdgeInsets(horizontal: full, top: half, bottom: half)
        let bottom = EdgeInsets(horizontal: full, top: half, bottom: full)

        if let first = images.first {
          ImageCollectionDetailItemView(
            image: first,
            margin: margin,
            insets: top,
            liveTextIcon: icon,
            scrollSidebar: scrollSidebar
          )
        }

        ForEach(images.dropFirst().dropLast()) { image in
          ImageCollectionDetailItemView(
            image: image,
            margin: margin,
            insets: middle,
            liveTextIcon: icon,
            scrollSidebar: scrollSidebar
          )
        }

        if images.isMany, let last = images.last {
          ImageCollectionDetailItemView(
            image: last,
            margin: margin,
            insets: bottom,
            liveTextIcon: icon,
            scrollSidebar: scrollSidebar
          )
        }
      }.listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .overlay(alignment: .bottomTrailing) {
      // TODO: Replace !images.isEmpty for !inspections.isEmpty
      let visible = showingDetails && !images.isEmpty

      Form {
        LabeledContent {
          Text("Screenshot 2023-09-10 at 4.26.56 PM.png")
        } label: {
          Image(systemName: "tag")
        }
      }
      .padding()
      .background(.thickMaterial.shadow(.drop(radius: 2)), in: .rect(cornerRadius: 8))
      .padding()
      .padding(.trailing, full)
      .visible(visible)
      // TODO: Come up with an animation I like.
      //
      // Because the toggle button in the toolbar changes instantly, this feels too slow. However, passing a duration
      // parameter throws away interrupted animations.
      .animation(.default.speed(3), value: visible)
    }.toolbar {
      let icons = Binding {
        icon
      } set: {
        liveTextIcon = $0
      }

      if liveText && !images.isEmpty {
        Toggle("Show Live Text icon", systemImage: "text.viewfinder", isOn: icons)
          .keyboardShortcut("t", modifiers: .command)
          .help("Show Live Text icon")
      }

//      if !images.isEmpty {
//        Toggle("Show Image Details", systemImage: "info.circle", isOn: $showingDetails)
//          .keyboardShortcut("i", modifiers: .command)
//          .help("Show Image Details")
//      }
    }.task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }
  }
}
