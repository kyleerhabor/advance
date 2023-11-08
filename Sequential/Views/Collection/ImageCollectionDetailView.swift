//
//  ImageCollectionDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import OSLog
import SwiftUI

struct ImageCollectionDetailItemBookmarkView: View {
  @Environment(\.collection) private var collection

  let image: ImageCollectionItemImage

  var body: some View {
    Button {
      image.item.bookmarked.toggle()
      collection.wrappedValue.updateBookmarks()
    } label: {
      Label(image.item.bookmarked ? "Remove Bookmark" : "Bookmark", systemImage: "bookmark")
    }
  }
}

struct ScrollPositionPreferenceKey: PreferenceKey {
  static var defaultValue = CGPoint.zero

  static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    let next = nextValue()

    guard next != .zero else {
      return
    }

    value = next
  }
}

struct VisiblePreferenceKey: PreferenceKey {
  static var defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {}
}

struct ImageCollectionDetailItemVisibilityView: View {
  @Environment(\.collection) private var collection

  let image: ImageCollectionItemImage

  var body: some View {
    GeometryReader { proxy in
      let container = proxy.frame(in: .scrollView)
      let frame = proxy.frame(in: .local)
      
      Color.clear
        .preference(key: ScrollPositionPreferenceKey.self, value: container.origin)
        .preference(key: VisiblePreferenceKey.self, value: frame.intersects(container))
    }
    // If the user scrolls fast enough where the image hasn't been rendered into the UI yet, they may see the
    // default title instead. A solution would be to work in an append-only mode (which would make for good use in
    // an ordered set)
    .onPreferenceChange(VisiblePreferenceKey.self) { visible in
      guard visible else {
        if let index = collection.wrappedValue.visible.firstIndex(of: image) {
          collection.wrappedValue.visible.remove(at: index)
        }

        return
      }

      collection.wrappedValue.visible.append(image)
    }
  }
}

struct ImageCollectionDetailItemView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.collapseMargins.key) private var collapse = Keys.collapseMargins.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.trackCurrentImage.key) private var trackCurrentImage = Keys.trackCurrentImage.value
  @State private var error: String?

  let image: ImageCollectionItemImage
  let margin: Double
  let insets: EdgeInsets
  var liveTextIcon: Bool
  let scrollSidebar: () -> Void

  var body: some View {
    let url = image.url
    let insets = collapse ? insets : .init(margin * 6)
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    ImageCollectionItemView(image: image) { $phase in
      VStack {
        if phase.image != nil && liveText {
          @Bindable var image = image

          LiveTextView(
            scope: image,
            orientation: image.orientation,
            analysis: $image.analysis
          ).supplementaryInterfaceHidden(!liveTextIcon)
        }
      }.background {
        if trackCurrentImage {
          ImageCollectionDetailItemVisibilityView(image: image)
        }
      }.onDisappear {
        // This is necessary to slow down the memory creep SwiftUI creates when rendering some images. It does not
        // eliminate it, but severely halts it. As an example, I have a copy of the first volume of Soloist in a Cage (~750 MBs).
        // When the window size is the default and the sidebar is open but hasn't been scrolled through, by time I
        // reach page 24, the memory has ballooned to ~600 MB. With this little trick, however, it rests at about ~150-200 MBs,
        // and is nearly eliminated by the window being closed. Note that the memory creep is mostly applicable to
        // regular memory and not so much real memory. In addition, not all image collections need it, since there are
        // some which (magically) handle their own memory while not destroying the image (in other words, it rests at a
        // good average, like ~150 MB).
        //
        // In the future, I'd like to improve image loading so images are preloaded before they appear on-screen. I've
        // tried this before, but it's resulted in microhangs.
        phase = .empty
      }
    }
    .shadow(radius: margin / 2)
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
        ImageCollectionCopyDestinationView(error: $error) { [image] }
      }

      Divider()

      ImageCollectionDetailItemBookmarkView(image: image)
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

  let images: [ImageCollectionItemImage]
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
          ).id(first.id)
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
          ).id(last.id)
        }
      }.listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .toolbar(id: "Canvas") {
      ToolbarItem(id: "Live Text Icon") {
        let icons = Binding {
          icon
        } set: {
          liveTextIcon = $0
        }

        let title = "\(icon ? "Hide" : "Show") Live Text icon"

        Toggle(title, systemImage: "text.viewfinder", isOn: icons)
          .keyboardShortcut(.liveTextIcon)
          .help(title)
      }
    }.task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }
  }
}
