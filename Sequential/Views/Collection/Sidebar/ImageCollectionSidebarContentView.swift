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

  let scrollDetail: Scroller.Scroll

  var body: some View {
    let selection = Binding {
      self.selection
    } set: { selection in
      scrollDetail(selection)

      self.selection = selection
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
      //
      // TODO: Order bookmarks based on items.
      //
      // Bookmarks can be the core backing store, while items can be user preferences, followed by images as final
      // materialized state. This would be required to preserve order for operations like moving and initial resolving.
      ForEach(bookmarks ? collection.wrappedValue.bookmarked : collection.wrappedValue.images, id: \.id) { image in
        ImageCollectionSidebarItemView(image: image)
      }
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
    }).focusedValue(\.sidebarBookmarked, .init {
      isBookmarked(selection: self.selection)
    } set: { bookmarked in
      bookmark(images: images(from: self.selection), value: bookmarked)
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
