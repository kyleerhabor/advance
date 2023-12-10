//
//  ImageCollectionDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import OSLog
import SwiftUI

struct VisibleItem<Item> {
  let item: Item
  let anchor: Anchor<CGRect>
}

extension VisibleItem: Equatable where Item: Equatable {}

// https://swiftwithmajid.com/2020/03/18/anchor-preferences-in-swiftui/
struct VisiblePreferenceKey<Item>: PreferenceKey {
  typealias Value = [VisibleItem<Item>]

  static var defaultValue: Value { [] }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.append(contentsOf: nextValue())
  }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
  typealias Value = [Anchor<CGRect>]

  static var defaultValue = Value()

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.append(contentsOf: nextValue())
  }
}

struct ImageCollectionDetailItemBookmarkView: View {
  @Environment(\.collection) private var collection

  @Binding var bookmarked: Bool
  var bookmark: Binding<Bool> {
    .init {
      bookmarked
    } set: { bookmarked in
      self.bookmarked = bookmarked
      collection.wrappedValue.updateBookmarks()
    }
  }

  var body: some View {
    ImageCollectionBookmarkView(bookmarked: bookmark)
  }
}

struct ImageCollectionDetailItemView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.collapseMargins.key) private var collapse = Keys.collapseMargins.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.resolveCopyDestinationConflicts.key) private var resolveCopyConflicts = Keys.resolveCopyDestinationConflicts.value
  @State private var isPresentingCopyDestinationPicker = false
  @State private var error: String?
  var isPresentingErrorAlert: Binding<Bool> {
    .init {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }
  }

  @Bindable var image: ImageCollectionItemImage
  let margin: Double
  let insets: EdgeInsets
  var liveTextIcon: Bool
  let scrollSidebar: Scroller.Scroll

  var body: some View {
    let url = image.url
    let insets = collapse ? insets : .init(margin * 6)

    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {
      ImageCollectionItemView(image: image) { $phase in
        if phase.image != nil && liveText {
          LiveTextView(
            scope: image,
            orientation: image.orientation,
            highlight: $image.highlighted,
            analysis: $image.analysis
          ).supplementaryInterfaceHidden(!liveTextIcon)
        }
      }
      .anchorPreference(key: VisiblePreferenceKey.self, value: .bounds) { [.init(item: image, anchor: $0)] }
      .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .bounds) { [$0] }
    }
    .listRowInsets(.listRow + insets)
    .shadow(radius: margin / 2)
    .contextMenu {
      Section {
        Button("Show in Finder") {
          openFinder(selecting: url)
        }

        Button("Show in Sidebar") {
          let selection: Set = [image.id]

          scrollSidebar(selection)

          self.selection = selection
        }
      }

      Section {
        Button("Copy", systemImage: "doc.on.doc") {
          if !NSPasteboard.general.write(items: [url as NSURL]) {
            Logger.ui.error("Failed to write URL \"\(url.string)\" to pasteboard")
          }
        }

        ImageCollectionCopyDestinationView(isPresented: $isPresentingCopyDestinationPicker, error: $error) { destination in
          Task(priority: .medium) {
            do {
              try await save(image: image, to: destination)
            } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }

      Section {
        ImageCollectionDetailItemBookmarkView(bookmarked: $image.bookmarked)
      }
    }.fileImporter(isPresented: $isPresentingCopyDestinationPicker, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task(priority: .medium) {
            do {
              try await save(image: image, to: url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        case .failure(let err):
          Logger.ui.info("\(err)")
      }
    }
    .fileDialogCopy()
    .alert(error ?? "", isPresented: isPresentingErrorAlert) {}
  }

  func save(image: ImageCollectionItemImage, to destination: URL) async throws {
    try ImageCollectionCopyDestinationView.saving {
      try destination.scoped {
        try ImageCollectionCopyDestinationView.saving(url: image, to: destination) { url in
          try image.scoped {
            try ImageCollectionCopyDestinationView.save(url: url, to: destination, resolvingConflicts: resolveCopyConflicts)
          }
        }
      }
    }
  }
}

struct ImageCollectionDetailView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var appLiveTextIcon = Keys.liveTextIcon.value
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @SceneStorage(Keys.liveTextIcon.key) private var liveTextIcon: Bool?

  let images: [ImageCollectionItemImage]
  let scrollSidebar: Scroller.Scroll
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

        Toggle("Live Text Icon", systemImage: "text.viewfinder", isOn: icons)
          .keyboardShortcut(.liveTextIcon)
          .help("\(icon ? "Hide" : "Show") Live Text icon")
      }
    }.backgroundPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage>.self) { items in
      GeometryReader { proxy in
        let local = proxy.frame(in: .local)
        let visible = items
          .filter { local.intersects(proxy[$0.anchor]) }
          .map(\.item)

        let highlight = Binding {
          if visible.isEmpty {
            return false
          }

          return visible.allSatisfy(\.highlighted)
        } set: { highlight in
          visible.forEach(setter(keyPath: \.highlighted, value: highlight))
        }

        // This code is really stupid, but really useful for one feature: toggling Live Text highlighting with Command-Shift-T.
        Toggle("Live Text Highlight", systemImage: "dot.viewfinder", isOn: highlight)
          .id(visible)
          .hidden()
          .keyboardShortcut(.liveTextHighlight)

        if let image = visible.last, displayTitleBarImage {
          let url = image.url

          // I would like to set .jumpToCurrentImage here, but whenever the identity changes, it causes a hang in large
          // image collections. This seems to be due to the modifier itself (since I imagine it happens in the sidebar)
          // but, interestingly, only seems to occur when the user scrolls down (and not up).
          Color.clear
            .navigationTitle(Text(url.deletingPathExtension().lastPathComponent))
            .navigationDocument(url)
        }
      }
    }.task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }
  }
}
