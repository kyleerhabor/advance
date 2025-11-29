//
//  ImageCollectionSidebarContentView.swift
//  Advance
//
//  Created by Kyle Erhabor on 10/11/23.
//

import Defaults
import Combine
import QuickLook
import OSLog
import SwiftUI

struct ImageCollectionSidebarBookmarkButtonView: View {
  let title: LocalizedStringKey
  @Binding var showing: Bool

  var body: some View {
    Toggle(title, systemImage: "bookmark", isOn: $showing)
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .toggleStyle(.button)
      .symbolVariant(showing ? .fill : .none)
      .foregroundStyle(Color(showing ? .controlAccentColor : .secondaryLabelColor))
  }
}

struct ImageCollectionSidebarFilterView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.imagesID) private var id
  @FocusState private var isSearchFocused
  @State private var priorSearch: String?
  private var isSearching: Bool {
    !collection.sidebarSearch.isEmpty
  }

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      Button("Search.Interaction", systemImage: "magnifyingglass") {
        // The reason we're doing it like this is because search may already be focused but not reflected in the sidebar.
        // In other words, this button performs a search. We don't always need to, since isSearchFocused changing its
        // state also triggers a search.
        if isSearchFocused {
          search()
        } else {
          isSearchFocused = true
        }
      }
      .buttonStyle(.borderless)
      .labelStyle(.iconOnly)
      .help("Search.Interaction")

      @Bindable var collect = collection

      // TODO: Figure out how to disallow tabbing when the user is not searching
      TextField("Search", text: $collect.sidebarSearch, prompt: Text(isSearchFocused ? "Search" : ""))
        .textFieldStyle(.plain)
        .font(.subheadline)
        .focused($isSearchFocused)
        .focusedSceneValue(\.sidebarSearch, .init(identity: id, enabled: true) {
          withAnimation {
//            columns = .all
          } completion: {
            isSearchFocused = true
          }
        })
        .onSubmit {
          search()
        }.onChange(of: isSearchFocused) {
          if isSearchFocused {
            priorSearch = collection.sidebarSearch

            return
          }

          // If the search hasn't changes, don't bother. This (partially) prevents an annoyance where the user will
          // start searching, cancel the operation, and see the list move from the page of the current image changing
          // (i.e. going from .images to .search). It's more-so an issue with the current image tracker, but something
          // we can mitigate here. In the future, we should patch the actual problem.
          if collection.sidebarSearch == priorSearch {
            return
          }

          search()
        }

      let showingBookmarks = collection.sidebarPage == \.bookmarks
      let showing = Binding {
        showingBookmarks
      } set: { show in
        collection.sidebarPage = show ? \.bookmarks : \.images

        collection.updateBookmarks()
      }

      let title: LocalizedStringKey = showingBookmarks ? "Images.Bookmarks.Hide" : "Images.Bookmarks.Show"

      ImageCollectionSidebarBookmarkButtonView(title: title, showing: showing)
        .help(title)
        .visible(!isSearching)
        .disabled(isSearching)
        .overlay {
          Button("Clear", systemImage: "xmark.circle.fill", role: .cancel) {
            collection.sidebarSearch = ""

            search()
          }
          .buttonStyle(.borderless)
          .labelStyle(.iconOnly)
          .imageScale(.small)
          .visible(isSearching)
          .disabled(!isSearching)
        }
    }
  }

  func search() {
    collection.sidebarPage = \.search

    collection.updateBookmarks()
  }
}

struct ImageCollectionSidebarItemView: View {
  @Bindable var image: ImageCollectionItemImage

  var body: some View {
    VStack {
      ImageCollectionItemImageView(image: image)
        .aspectRatio(image.properties.sized.aspectRatio, contentMode: .fit)

      // Interestingly, this can be slightly expensive.
      let path = image.url.lastPathComponent

      Text(path)
        .font(.subheadline)
        .padding(EdgeInsets(vertical: 4, horizontal: 8))
        .background(.fill.tertiary, in: .rect(cornerRadius: 4))
        // TODO: Replace this for an expansion tooltip (like how NSTableView has it)
        //
        // I tried this before, but couldn't get sizing or the trailing ellipsis to work properly.
        .help(path)
    }
    // This is not an image editor, but I don't mind some functionality that's associated with image editors. Being
    // able to drag images out of the app and drop them elsewhere just feels natural.
    .draggable(image.url) {
      ImageCollectionItemImageView(image: image)
    }
  }
}

struct ImageCollectionSidebarContentView: View {
  typealias VisibleImageIDsPreferenceKey = VisiblePreferenceKey<ImageCollectionItemImage.ID>

  @Environment(ImageCollection.self) private var collection
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(\.imagesID) private var id
//  @Environment(\.detailScroller) private var detailScroller
  
  @State private var quicklookItem: URL?
  @State private var quicklookItems = [URL]()
  @State private var quicklookSelection = Set<ImageCollectionItemImage.ID>()
  @State private var quicklookScopes = [ImageCollectionItemImage: ImageCollectionItemImage.SecurityScope]()

  @State private var isCopyingFileImporterPresented = false
  @State private var copyingSelection = ImageCollectionSidebar.Selection()
  @State private var error: String?
  private var selection: ImageCollectionSidebar.Selection { sidebar.selection }
  private var selected: Binding<ImageCollectionSidebar.Selection> {
    .init {
      selection
    } set: { selection in
      let difference = selection.subtracting(self.selection)
      let id = sidebar.images.last { difference.contains($0.id) }?.id

      if let id {
//        detailScroller.scroll(id)
      }

      sidebar.selection = selection
    }
  }
  private var isErrorPresented: Binding<Bool> {
    .init {
      error != nil
    } set: { present in
      if !present {
        error = nil
      }
    }
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(selection: selected) {
        ForEach(sidebar.images) { image in
          ImageCollectionSidebarItemView(image: image)
            .anchorPreference(key: VisibleImageIDsPreferenceKey.self, value: .bounds) {
              [VisibleItem(item: image.id, anchor: $0)]
            }
        }
//        .onMove { from, to in
//          collection.order.elements.move(fromOffsets: from, toOffset: to)
//          collection.update()
//
//          Task(priority: .medium) {
//            do {
//              try await collection.persist(id: id)
//            } catch {
//              Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar image move): \(error)")
//            }
//          }
//        }
//        // This adds a "Delete" menu item under Edit.
//        .onDelete { offsets in
//          collection.order.elements.remove(atOffsets: offsets)
//          collection.update()
//
//          Task(priority: .medium) {
//            do {
//              try await collection.persist(id: id)
//            } catch {
//              Logger.model.error("Could not persist image collection \"\(id)\" (via menu bar delete): \(error)")
//            }
//          }
//        }
      }
      .onChange(of: collection.sidebarPage) {

      }
//      .backgroundPreferenceValue(VisibleImageIDsPreferenceKey.self) { items in
//        GeometryReader { proxy in
//          let local = proxy.frame(in: .local)
//          let id = items
//            .filter { local.contains(proxy[$0.anchor]) }
//            .middle?.item
//
//          Color.clear.onChange(of: id) {
//            sidebar.current = id
//          }
//        }
//      }
//      .onDeleteCommand {
//        collection.order.subtract(selection)
//        collection.update()
//
//        Task(priority: .medium) {
//          do {
//            try await collection.persist(id: id)
//          } catch {
//            Logger.model.error("Could not persist image collection \"\(id)\" (via delete key): \(error)")
//          }
//        }
//      }
//      .onChange(of: collection.sidebarPage) {
//        guard let id = sidebar.current else {
//          return
//        }
//
//        proxy.scrollTo(id, anchor: .center)
//      }
    }
//    .safeAreaInset(edge: .bottom, spacing: 0) {
//      VStack(spacing: 0) {
//        Divider()
//
//        ImageCollectionSidebarFilterView()
//          .padding(8)
//      }
//    }
//    .copyable(urls(from: selection))
//    // TODO: Figure out how to extract this.
//    //
//    // I tried moving this into a ViewModifier and View, but the passed binding for the selected item wouldn't always
//    // be reflected (or sometimes just crash).
//    .quickLookPreview($quicklookItem, in: quicklookItems)
//    .contextMenu { ids in
//      let bookmarked = Binding {
//        !ids.isEmpty && isBookmarked(selection: ids)
//      } set: { isOn in
//        self.bookmark(images: images(from: ids), value: isOn)
//      }
//
//      Section {
//        let quicklook = Binding<Bool> {
//          quicklookItem != nil && ids.isSubset(of: quicklookSelection)
//        } set: { isOn in
//          quicklookSelection = isOn ? ids : []
//
//          updateQuicklook()
//        }
//
//        ImageCollectionQuickLookView(isOn: quicklook)
//      }
//
//      Section {
//        Button("Copy") {
//          let urls = urls(from: ids)
//
//          if !NSPasteboard.general.write(items: urls as [NSURL]) {
//            Logger.ui.error("Failed to write URLs \"\(urls.map(\.string))\" to pasteboard")
//          }
//        }
//
//        let isPresented = Binding {
//          isCopyingFileImporterPresented
//        } set: { isPresenting in
//          isCopyingFileImporterPresented = isPresenting
//          copyingSelection = ids
//        }
//
//        ImageCollectionCopyingView(isPresented: isPresented) { destination in
//          Task(priority: .medium) {
//            do {
//              try await copy(images: images(from: ids), to: destination)
//            } catch {
//              self.error = error.localizedDescription
//            }
//          }
//        }
//      }
//
//      Section {
//        ImageCollectionBookmarkView(isOn: bookmarked)
//      }
//    }
//    .fileImporter(isPresented: $isCopyingFileImporterPresented, allowedContentTypes: [.folder]) { result in
//      switch result {
//        case .success(let url):
//          Task(priority: .medium) {
//            do {
//              try await copy(images: images(from: copyingSelection), to: url)
//            } catch {
//              self.error = error.localizedDescription
//            }
//          }
//        case .failure(let err):
//          Logger.ui.error("Could not import folder for copying operation: \(err)")
//      }
//    }
//    .fileDialogCopy()
//    .alert(self.error ?? "", isPresented: isErrorPresented) {}
//    .focusedValue(\.imagesQuickLook, .init(
//      identity: quicklookSelection,
//      enabled: quicklookItem != nil || !selection.isEmpty,
//      state: quicklookItem != nil
//    ) { quicklook in
//      quicklookSelection = quicklook ? selection : []
//
//      updateQuicklook()
//    })
//    .focusedValue(\.bookmark, .init(
//      identity: selection,
//      enabled: !selection.isEmpty,
//      state: !selection.isEmpty && isBookmarked(selection: selection)
//    ) { isOn in
//      self.bookmark(images: images(from: selection), value: isOn)
//    })
//    .onDisappear {
//      quicklookSelection.removeAll()
//
//      updateQuicklook()
//    }
//    .onKeyPress(.space, phases: .down) { _ in
//      quicklookSelection = selection
//
//      updateQuicklook()
//
//      return .handled
//    }
  }

  func images(from selection: ImageCollectionSidebar.Selection) -> [ImageCollectionItemImage] {
    collection.images.filter(in: selection, by: \.id)
  }

  func urls(from selection: ImageCollectionSidebar.Selection) -> [URL] {
    images(from: selection).map(\.url)
  }

  func updateQuicklook() {
    quicklookScopes.forEach { (image, scope) in
      if quicklookSelection.contains(image.id) {
        return
      }

      image.endSecurityScope(scope)

      quicklookScopes[image] = nil
    }

    let images = images(from: quicklookSelection)

    images
      .filter { quicklookScopes[$0] == nil }
      .forEach { image in
        quicklookScopes[image] = image.startSecurityScope()
      }

    quicklookItems = images.map(\.url)
    quicklookItem = if let url = quicklookItem, quicklookItems.contains(where: { $0 == url }) {
      quicklookItem
    } else {
      quicklookItems.first
    }
  }

  func isBookmarked(selection: Set<ImageCollectionItemImage.ID>) -> Bool {
    return selection.isSubset(of: collection.bookmarks)
  }

  func bookmark(images: some Sequence<ImageCollectionItemImage>, value: Bool) {
    images.forEach(setter(on: \.bookmarked, value: value))
    
    collection.updateBookmarks()

    Task(priority: .medium) {
      do {
        try await collection.persist(id: id)
      } catch {
        Logger.model.error("Could not persist image collection \"\(id)\" from sidebar bookmark: \(error)")
      }
    }
  }

  nonisolated func copy(images: some Sequence<ImageCollectionItemImage>, to destination: URL) async throws {
    try await Self.copy(images: images, to: destination, resolvingConflicts: true)
  }

  nonisolated static func copy(
    images: some Sequence<ImageCollectionItemImage>,
    to destination: URL,
    resolvingConflicts resolveConflicts: Bool
  ) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.accessingSecurityScopedResource {
        try images.forEach { image in
          try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
            try image.accessingSecurityScopedResource {
              try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveConflicts)
            }
          }
        }
      }
    }
  }
}
