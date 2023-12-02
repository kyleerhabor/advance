//
//  ImageCollectionSidebarContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/11/23.
//

import QuickLook
import OSLog
import SwiftUI

struct ImageCollectionSidebarBookmarkButtonView: View {
  @Binding var bookmarks: Bool

  var body: some View {
    // We could use ImageCollectionBookmarkView, but that uses a Button.
    Toggle("\(bookmarks ? "Hide" : "Show") Bookmarks", systemImage: "bookmark", isOn: $bookmarks)
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .toggleStyle(.button)
      .symbolVariant(bookmarks ? .fill : .none)
      .foregroundStyle(Color(bookmarks ? .controlAccentColor : .secondaryLabelColor))
  }
}

struct ImageCollectionSidebarItemView: View {
  let image: ImageCollectionItemImage

  var body: some View {
    VStack {
      ImageCollectionItemView(image: image)
        .overlay(alignment: .topTrailing) {
          Image(systemName: "bookmark")
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .opacity(0.8)
            .imageScale(.large)
            .shadow(radius: 0.5)
            .padding(4)
            .visible(image.item.bookmarked)
        }

      // Interestingly, this can be slightly expensive.
      let path = image.url.lastPathComponent

      Text(path)
        .font(.subheadline)
        .padding(.init(vertical: 4, horizontal: 8))
        .background(Color.secondaryFill)
        .clipShape(.rect(cornerRadius: 4))
        // TODO: Replace this for an expansion tooltip (like how NSTableView has it)
        //
        // I tried this before, but couldn't get sizing or the trailing ellipsis to work properly.
        .help(path)
    }
    // This is not an image editor, but I don't mind some functionality that's associated with image editors. Being
    // able to drag images out of the app and drop them elsewhere just feels natural.
    .draggable(image.url) {
      ImageCollectionItemView(image: image)
    }
  }
}

struct ImageCollectionSidebarItem {
  let id: UUID
  let visible: Bool
  let position: CGFloat
}

struct ImageCollectionSidebarItemVisibleView: View {
  let id: ImageCollectionItemImage.ID

  var body: some View {
    GeometryReader { proxy in
      let container = proxy.frame(in: .scrollView)
      let local = proxy.frame(in: .local)

      Color.clear.preference(
        key: VisiblePreferenceKey.self,
        value: local.intersects(container)
//        key: ImageCollectionSidebarItemPreferenceKey.self,
//        value: .init(
//          id: id,
//          // Note: This is a little *too* loose. It should really say "if it's fully contained within", but .contains
//          // doesn't seem to be right here.
//          visible: local.intersects(container),
//          position: container.origin.y
//        )
      )
    }
  }
}

extension ImageCollectionSidebarItem: Comparable {
  static func <(lhs: Self, rhs: Self) -> Bool {
    lhs.position < rhs.position
  }
}

struct ImageCollectionSidebarItemPreferenceKey: PreferenceKey {
  static var defaultValue = ImageCollectionSidebarItem(id: .init(), visible: false, position: .zero)

  static func reduce(value: inout ImageCollectionSidebarItem, nextValue: () -> ImageCollectionSidebarItem) {
    let next = nextValue()

    guard next.visible else {
      return
    }

    value = max(value, next)
  }
}

struct ImageCollectionSidebarContentView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.resolveCopyDestinationConflicts.key) private var resolveCopyConflicts = Keys.resolveCopyDestinationConflicts.value
  @State private var items = [ImageCollectionItemImage.ID]()
  @State private var bookmarks = false
  @State private var selectedQuickLookItem: URL?
  @State private var quickLookItems = [URL]()
  @State private var quickLookScopes = [ImageCollectionItemImage: ImageCollectionItemImage.Scope]()
  @State private var selectedCopyFiles = ImageCollectionView.Selection()
  @State private var isPresentingCopyFilePicker = false
  @State private var error: String?
  private var selected: Binding<ImageCollectionView.Selection> {
    .init {
      self.selection
    } set: { selection in
      // FIXME: This is a noop on the first call.
      scrollDetail(selection)

      self.selection = selection
    }
  }
  private var filtering: Bool { bookmarks }

  let scrollDetail: Scroller.Scroll

  var body: some View {
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    // TODO: Generalize the visibility code, make it persistable, and apply it to the detail view.
    //
    // This would allow users to continue where they left off. The main thing stopping this is data is loaded after the
    // view is, so we'd need to know when the view is ready.
    //
    // TODO: Package certain variables into one state for the sidebar.
    //
    // The main point of this would be to separate selection state between non-filtered and filtered bookmarks. There
    // may be states added later, which is why I want to package it into one simple interface.
    ScrollViewReader { proxy in
      List(selection: selected) {
        // TODO: Figure out how to support tabs.
        //
        // This works, but it resets the user's scrolling position whenever bookmarks is flipped.
        //
        // TODO: Order bookmarks based on items.
        //
        // Bookmarks can be the core backing store, while items can be user preferences, followed by images as final
        // materialized state. This would be required to preserve order for operations like moving and initial resolving.
        ForEach(bookmarks ? collection.wrappedValue.bookmarked : collection.wrappedValue.images, id: \.id) { image in
          ImageCollectionSidebarItemView(image: image)
            .background {
              ImageCollectionSidebarItemVisibleView(id: image.id)
                .onPreferenceChange(VisiblePreferenceKey.self) { visible in
                  guard visible else {
                    if let index = items.firstIndex(of: image.id) {
                      items.remove(at: index)
                    }

                    return
                  }

                  items.append(image.id)
                }
            }
        }
      }.onChange(of: filtering) {
        let items = Set(items)

        guard !filtering, let item = collection.wrappedValue.images.last(where: { items.contains($0.id) })?.id else {
          return
        }

        proxy.scrollTo(item, anchor: .center)
      }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      // I would *really* like this at the top, but I can't justify it since this is more a filter and not a new tab.
      VStack(alignment: .trailing, spacing: 0) {
        Divider()

        ImageCollectionSidebarBookmarkButtonView(bookmarks: $bookmarks)
          .padding(8)
      }
    }
    .copyable(urls(from: selection))
    // TODO: Figure out how to extract this.
    //
    // I tried moving this into a ViewModifier and View, but the passed binding for the selected item wouldn't always
    // be reflected.
    .quickLookPreview($selectedQuickLookItem, in: quickLookItems)
    .contextMenu { ids in
      Section {
        Button("Show in Finder") {
          openFinder(selecting: urls(from: ids))
        }

        // I tried replacing this for a Toggle, but the shift in items for the toggle icon didn't make it look right,
        // defeating the purpose.
        Button("Quick Look", systemImage: "eye") {
          guard selectedQuickLookItem == nil else {
            selectedQuickLookItem = nil

            return
          }

          quicklook(images: images(from: ids))
        }
      }

      Section {
        Button("Copy") {
          let urls = urls(from: ids)

          if !NSPasteboard.general.write(items: urls as [NSURL]) {
            Logger.ui.error("Failed to write URLs \"\(urls.map(\.string))\" to pasteboard")
          }
        }

        let isPresented = Binding {
          isPresentingCopyFilePicker
        } set: { isPresenting in
          isPresentingCopyFilePicker = isPresenting
          selectedCopyFiles = ids
        }

        ImageCollectionCopyDestinationView(isPresented: isPresented, error: $error) { destination in
          Task(priority: .medium) {
            do {
              try await save(images: images(from: ids), to: destination)
            } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }

      Section {
        let marked = Binding {
          isBookmarked(selection: ids)
        } set: { bookmarked in
          bookmark(images: images(from: ids), value: bookmarked)
        }

        ImageCollectionBookmarkView(bookmarked: marked)
      }
    }.fileImporter(isPresented: $isPresentingCopyFilePicker, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task(priority: .medium) {
            do {
              try await save(images: images(from: selectedCopyFiles), to: url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        case .failure(let err):
          Logger.ui.info("\(err)")
      }
    }
    .fileDialogCopy()
    .alert(self.error ?? "", isPresented: error) {}
    .task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }.onDisappear {
      clearQuickLookItems()
    }.onKeyPress(.space, phases: .down) { _ in
      quicklook(images: images(from: selection))

      return .handled
    }.focusedValue(\.sidebarFinder, .init(enabled: !selection.isEmpty) {
      openFinder(selecting: urls(from: selection))
    }).focusedValue(\.sidebarQuicklook, .init(enabled: !selection.isEmpty || selectedQuickLookItem != nil) {
      guard selectedQuickLookItem == nil else {
        selectedQuickLookItem = nil

        return
      }

      quicklook(images: images(from: selection))
    }).focusedValue(\.sidebarBookmarked, .init {
      isBookmarked(selection: selection)
    } set: { bookmarked in
      bookmark(images: images(from: selection), value: bookmarked)
    })
  }

  func images(from selection: ImageCollectionView.Selection) -> [ImageCollectionItemImage] {
    collection.wrappedValue.images.filter(in: selection, by: \.id)
  }

  func urls(from selection: ImageCollectionView.Selection) -> [URL] {
    images(from: selection).map(\.url)
  }

  func clearQuickLookItems() {
    quickLookScopes.forEach { (image, scope) in
      image.endSecurityScope(scope: scope)
    }

    quickLookScopes = [:]
  }

  func quicklook(images: [ImageCollectionItemImage]) {
    clearQuickLookItems()

    images.forEach { image in
      // If we hooked into Quick Look directly, we could likely avoid this lifetime juggling taking place here.
      quickLookScopes[image] = image.startSecurityScope()
    }

    quickLookItems = images.map(\.url)
    selectedQuickLookItem = quickLookItems.first
  }

  func bookmarked(selection: ImageCollectionView.Selection) -> Bool {
    return selection.isSubset(of: collection.wrappedValue.bookmarkedIndex)
  }

  func isBookmarked(selection: ImageCollectionView.Selection) -> Bool {
    if selection.isEmpty {
      return false
    }

    return bookmarked(selection: selection)
  }

  func bookmark(images: some Sequence<ImageCollectionItemImage>, value: Bool) {
    images.forEach(setter(keyPath: \.bookmarked, value: value))
    
    collection.wrappedValue.updateBookmarks()
  }

  func save(images: [ImageCollectionItemImage], to destination: URL) async throws {
    try ImageCollectionCopyDestinationView.saving {
      try destination.scoped {
        try images.forEach { image in
          try ImageCollectionCopyDestinationView.saving(url: image, to: destination) { url in
            try image.scoped {
              try ImageCollectionCopyDestinationView.save(url: url, to: destination, resolvingConflicts: resolveCopyConflicts)
            }
          }
        }
      }
    }
  }
}
