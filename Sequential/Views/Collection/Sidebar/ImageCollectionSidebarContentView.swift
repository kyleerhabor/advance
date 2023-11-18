//
//  ImageCollectionSidebarContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/11/23.
//

import QuickLook
import OSLog
import SwiftUI

struct ImageCollectionSidebarContentView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.resolveCopyDestinationConflicts.key) private var resolveCopyConflicts = Keys.resolveCopyDestinationConflicts.value
  @State private var selectedQuickLookItem: URL?
  @State private var quickLookItems = [URL]()
  @State private var quickLookScopes = [ImageCollectionItemImage: ImageCollectionItemImage.Scope]()
  @State private var bookmarks = false
  @State private var selectedCopyFiles = ImageCollectionView.Selection()
  @State private var isPresentingCopyFilePicker = false
  @State private var error: String?

  let scrollDetail: () -> Void

  var body: some View {
    let selection = Binding {
      self.selection
    } set: { selection in
      self.selection = selection

      scrollDetail()
    }
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    List(selection: selection) {
      // TODO: Figure out how to support tabs.
      //
      // This works, but it resets the user's scrolling position whenever bookmarks is flipped.
      ForEach(bookmarks ? collection.wrappedValue.bookmarked : collection.wrappedValue.images, id: \.id) { image in
        ImageCollectionSidebarItemView(image: image)
      }
      // TODO: Order bookmarks based on items.
      //
      // Bookmarks can be the core backing store, while items can be user preferences, followed by images as final
      // materialized state. This would be required to preserve order for operations like moving and initial resolving.
//      .onMove { source, destination in
//        collection.wrappedValue.items.move(fromOffsets: source, toOffset: destination)
//        collection.wrappedValue.updateImages()
//      }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      // I would *really* like this at the top, but I can't justify it since this is more a filter and not a new tab.
      VStack(alignment: .trailing, spacing: 0) {
        Divider()

        ImageCollectionSidebarBookmarkButtonView(bookmarks: $bookmarks)
          .padding(8)
      }
    }
    .copyable(urls(from: self.selection))
    // TODO: Figure out how to extract this.
    //
    // I tried moving this into a ViewModifier and View, but the passed binding for the selected item wouldn't always
    // be reflected.
    .quickLookPreview($selectedQuickLookItem, in: quickLookItems)
    .contextMenu { ids in
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

      Divider()

      // Should we state how many images will be copied?
      Button("Copy", systemImage: "doc.on.doc") {
        let urls = urls(from: ids)

        if !NSPasteboard.general.write(items: urls as [NSURL]) {
          Logger.ui.error("Failed to write URLs \"\(urls.map(\.string))\" to pasteboard")
        }
      }

      if !copyDepot.resolved.isEmpty {
        let isPresented = Binding {
          isPresentingCopyFilePicker
        } set: { isPresenting in
          isPresentingCopyFilePicker = isPresenting
          selectedCopyFiles = ids
        }

        ImageCollectionCopyDestinationView(isPresented: isPresented, error: $error) { images(from: ids) }
      }

      Divider()

      let mark: Bool = bookmark(selection: ids)

      Button {
        bookmark(mark, selection: ids)
      } label: {
        Label(mark ? "Bookmark" : "Remove Bookmark", systemImage: "bookmark")
      }
    }.fileImporter(isPresented: $isPresentingCopyFilePicker, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task {
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
    .alert(self.error ?? "", isPresented: error) {}
    .task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }.onDisappear {
      clearQuickLookItems()
    }.onKey(" ") {
      quicklook(images: images(from: self.selection))
    }.focusedValue(\.sidebarFinder, .init(enabled: !self.selection.isEmpty) {
      openFinder(selecting: urls(from: self.selection))
    }).focusedValue(\.sidebarQuicklook, .init(enabled: !self.selection.isEmpty || selectedQuickLookItem != nil) {
      guard selectedQuickLookItem == nil else {
        selectedQuickLookItem = nil

        return
      }

      quicklook(images: images(from: self.selection))
    }).focusedValue(\.sidebarBookmark, .init(enabled: !self.selection.isEmpty) {
      bookmark(selection: self.selection)
    }).focusedValue(\.sidebarBookmarkState, bookmark(selection: self.selection) ? .add : .remove)
  }

  func images(from selection: ImageCollectionView.Selection) -> [ImageCollectionItemImage] {
    collection.wrappedValue.images.filter(in: selection, by: \.id)
  }

  func urls(from selection: ImageCollectionView.Selection) -> [URL] {
    images(from: selection).map(\.url)
  }

  func quicklook(images: [ImageCollectionItemImage]) {
    clearQuickLookItems()

    images.forEach { image in
      quickLookScopes[image] = image.startSecurityScope()
    }

    quickLookItems = images.map(\.url)
    selectedQuickLookItem = quickLookItems.first
  }

  func clearQuickLookItems() {
    quickLookScopes.forEach { (image, scope) in
      image.endSecurityScope(scope: scope)
    }

    quickLookScopes = [:]
  }

  func bookmark(selection: ImageCollectionView.Selection) -> Bool {
    guard selection.isEmpty else {
      return !selection.isSubset(of: collection.wrappedValue.bookmarkedIndex)
    }

    return true
  }

  func bookmark(selection: ImageCollectionView.Selection) {
    bookmark(bookmark(selection: selection), selection: selection)
  }

  func bookmark(_ value: Bool, selection: ImageCollectionView.Selection) {
    collection.wrappedValue.images.filter(in: selection, by: \.id).forEach { image in
      image.item.bookmarked = value
    }

    collection.wrappedValue.updateBookmarks()
  }

  func save(images: [ImageCollectionItemImage], to destination: URL) async throws {
    try ImageCollectionCopyDestinationView<ImageCollectionItemImage>.saving {
      try destination.scoped {
        try images.forEach { image in
          try ImageCollectionCopyDestinationView.saving(url: image, to: destination) { url in
            try image.scoped {
              try ImageCollectionCopyDestinationView<ImageCollectionItemImage>.save(url: url, to: destination, resolvingConflicts: resolveCopyConflicts)
            }
          }
        }
      }
    }
  }
}
