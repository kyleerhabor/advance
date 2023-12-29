//
//  ImageCollectionSidebarContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/11/23.
//

import Defaults
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
            .visible(image.bookmarked)
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

struct ImageCollectionSidebarContentView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.prerendering) private var prerendering
  @Environment(\.id) private var id
  @Environment(\.selection) @Binding private var selection
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @Default(.resolveCopyingConflicts) private var resolveConflicts
  @State private var item: ImageCollectionItemImage.ID?
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

    // TODO: Package certain variables into one state for the sidebar.
    //
    // The main point of this would be to separate selection state between non-filtered and filtered bookmarks. There
    // may be states added later, which is why I want to package it into one simple interface.
    ScrollViewReader { proxy in
      List(selection: selected) {
        ForEach(bookmarks ? collection.bookmarks : collection.images, id: \.id) { image in
          ImageCollectionSidebarItemView(image: image)
            .anchorPreference(key: VisiblePreferenceKey<ImageCollectionItemImage.ID>.self, value: .bounds) {
              [.init(item: image.id, anchor: $0)]
            }
        }.onMove { from, to in
          collection.order.elements.move(fromOffsets: from, toOffset: to)
          collection.update()
        }
        // This adds a "Delete" menu item under Edit.
        .onDelete { offsets in
          collection.order.elements.remove(atOffsets: offsets)
          collection.update()
        }
      }.backgroundPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage.ID>.self) { items in
        GeometryReader { proxy in
          Color.clear.onChange(of: items) {
            guard !filtering else {
              return
            }

            let local = proxy.frame(in: .local)
            let visibles = items
              .filter { local.contains(proxy[$0.anchor]) }
              .map(\.item)

            self.item = visibles.middle
          }
        }.onChange(of: filtering) {
          guard !filtering,
                let item else {
            return
          }

          // FIXME: When scrolling only the first few images (e.g. ~21) in a large collection (say, 200+), this may
          // always scroll to the beginning.
          proxy.scrollTo(item, anchor: .center)
        }
      }.onDeleteCommand {
        collection.order.subtract(selection)
        collection.update()
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

        ImageCollectionCopyingView(isPresented: isPresented, error: $error) { destination in
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
    .focusedValue(\.openFinder, .init(enabled: !selection.isEmpty, menu: .init(identity: selection) {
      openFinder(selecting: urls(from: selection))
    })).focusedValue(\.sidebarQuicklook, .init(enabled: !selection.isEmpty, menu: .init(identity: quickLookItems) {
      guard selectedQuickLookItem == nil else {
        selectedQuickLookItem = nil

        return
      }

      quicklook(images: images(from: selection))
    })).focusedValue(\.sidebarBookmarked, .init {
      isBookmarked(selection: selection)
    } set: { bookmarked in
      bookmark(images: images(from: selection), value: bookmarked)
    }).onDisappear {
      clearQuickLookItems()
    }.onKeyPress(.space, phases: .down) { _ in
      quicklook(images: images(from: selection))

      return .handled
    }
  }

  func images(from selection: ImageCollectionView.Selection) -> [ImageCollectionItemImage] {
    collection.images.filter(in: selection, by: \.id)
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
    return selection.isSubset(of: collection.bookmarkings)
  }

  func isBookmarked(selection: ImageCollectionView.Selection) -> Bool {
    if selection.isEmpty {
      return false
    }

    return bookmarked(selection: selection)
  }

  func bookmark(images: some Sequence<ImageCollectionItemImage>, value: Bool) {
    images.forEach(setter(keyPath: \.bookmarked, value: value))
    
    collection.updateBookmarks()

    Task(priority: .medium) {
      do {
        try await collection.persist(id: id)
      } catch {
        Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar bookmark): \(error)")
      }
    }
  }

  func save(images: [ImageCollectionItemImage], to destination: URL) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.scoped {
        try images.forEach { image in
          try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
            try image.scoped {
              try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveConflicts)
            }
          }
        }
      }
    }
  }
}
