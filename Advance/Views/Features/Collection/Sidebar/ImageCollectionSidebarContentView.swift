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
  @Environment(\.id) private var id
  @Environment(\.navigationColumns) @Binding private var columns
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
            columns = .all
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
  let image: ImageCollectionItemImage

  var body: some View {
    VStack {
      ImageCollectionItemView(image: image)
        .aspectRatio(image.properties.sized.aspectRatio, contentMode: .fit)
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
        .background(.fill.tertiary, in: .rect(cornerRadius: 4))
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
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(ImageCollectionPath.self) private var path
  @Environment(\.prerendering) private var prerendering
  @Environment(\.id) private var id
  @Environment(\.loaded) private var loaded
  @Environment(\.detailScroller) private var detailScroller
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
  @Default(.resolveCopyingConflicts) private var resolveCopyingConflicts
  
  @State private var quicklookItem: URL?
  @State private var quicklookItems = [URL]()
  @State private var quicklookSelection = Set<ImageCollectionItemImage.ID>()
  @State private var quicklookScopes = [ImageCollectionItemImage: ImageCollectionItemImage.Scope]()

  @State private var isCopyingFileImporterPresented = false
  @State private var copyingSelection = ImageCollectionSidebar.Selection()
  @State private var error: String?
  private var selection: ImageCollectionSidebar.Selection { sidebar.selection }
  private var selected: Binding<ImageCollectionSidebar.Selection> {
    .init {
      selection
    } set: { selection in
      defer {
        sidebar.selection = selection
      }

      let difference = selection.subtracting(self.selection)
      let id = sidebar.images.last { difference.contains($0.id) }?.id

      path.item = id

      guard let id else {
        return
      }

      path.items.insert(id)

      detailScroller.scroll(id)
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
            .anchorPreference(key: VisiblePreferenceKey<ImageCollectionItemImage.ID>.self, value: .bounds) {
              [.init(item: image.id, anchor: $0)]
            }
        }.onMove { from, to in
          collection.order.elements.move(fromOffsets: from, toOffset: to)
          collection.update()

          Task(priority: .medium) {
            do {
              try await collection.persist(id: id)
            } catch {
              Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar image move): \(error)")
            }
          }
        }
        // This adds a "Delete" menu item under Edit.
        .onDelete { offsets in
          collection.order.elements.remove(atOffsets: offsets)
          collection.update()

          Task(priority: .medium) {
            do {
              try await collection.persist(id: id)
            } catch {
              Logger.model.error("Could not persist image collection \"\(id)\" (via menu bar delete): \(error)")
            }
          }
        }
      }.backgroundPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage.ID>.self) { items in
        GeometryReader { proxy in
          let local = proxy.frame(in: .local)
          let id = items
            .filter { local.contains(proxy[$0.anchor]) }
            .middle?.item

          Color.clear.onChange(of: id) {
            sidebar.current = id
          }
        }
      }.onDeleteCommand {
        collection.order.subtract(selection)
        collection.update()

        Task(priority: .medium) {
          do {
            try await collection.persist(id: id)
          } catch {
            Logger.model.error("Could not persist image collection \"\(id)\" (via delete key): \(error)")
          }
        }
      }.onChange(of: collection.sidebarPage) {
        guard let id = sidebar.current else {
          return
        }

        proxy.scrollTo(id, anchor: .center)
      }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 0) {
        Divider()

        ImageCollectionSidebarFilterView()
          .padding(8)
      }
    }
    .copyable(urls(from: selection))
    // TODO: Figure out how to extract this.
    //
    // I tried moving this into a ViewModifier and View, but the passed binding for the selected item wouldn't always
    // be reflected (or sometimes just crash).
    .quickLookPreview($quicklookItem, in: quicklookItems)
    .contextMenu { ids in
      let bookmarked = Binding {
        !ids.isEmpty && isBookmarked(selection: ids)
      } set: { bookmarked in
        bookmark(images: images(from: ids), value: bookmarked)
      }

      Section {
        Button("Finder.Show") {
          openFinder(selecting: urls(from: ids))
        }

        Button("Quick Look") {
          clearQuicklook()
          setQuicklook(images: images(from: ids))
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
          isCopyingFileImporterPresented
        } set: { isPresenting in
          isCopyingFileImporterPresented = isPresenting
          copyingSelection = ids
        }

        ImageCollectionCopyingView(isPresented: isPresented) { destination in
          Task(priority: .medium) {
            do {
              try await copy(images: images(from: ids), to: destination)
            } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }

      Section {
        ImageCollectionBookmarkView(showing: bookmarked)
      }
    }.fileImporter(isPresented: $isCopyingFileImporterPresented, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task(priority: .medium) {
            do {
              try await copy(images: images(from: copyingSelection), to: url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        case .failure(let err):
          Logger.ui.info("\(err)")
      }
    }
    .fileDialogCopy()
    .alert(self.error ?? "", isPresented: isErrorPresented) {}
    .focusedValue(\.finderShow, .init(identity: selection, enabled: !selection.isEmpty) {
      openFinder(selecting: urls(from: selection))
    })
    .focusedValue(\.quicklook, .init(identity: quicklookSelection, enabled: !selection.isEmpty, state: quicklookItem != nil) {
      clearQuicklook()

      // Is it possible for this action to be called where quicklookItem is nil two times in a row? If so, we'd be
      // leaking security scoped resources.
      guard quicklookItem == nil else {
        quicklookItem = nil

        return
      }

      setQuicklook(images: images(from: selection))
    })
    .onDisappear {
      clearQuicklook()
    }.onKeyPress(.space, phases: .down) { _ in
      clearQuicklook()
      setQuicklook(images: images(from: selection))

      return .handled
    }
  }

  func images(from selection: ImageCollectionSidebar.Selection) -> [ImageCollectionItemImage] {
    collection.images.filter(in: selection, by: \.id)
  }

  func urls(from selection: ImageCollectionSidebar.Selection) -> [URL] {
    images(from: selection).map(\.url)
  }

  func clearQuicklook() {
    quicklookScopes.forEach { (image, scope) in
      image.endSecurityScope(scope: scope)
    }
  }

  func setQuicklook(images: [ImageCollectionItemImage]) {
    quicklookScopes = .init(uniqueKeysWithValues: images.map { ($0, $0.startSecurityScope()) })
    quicklookItems = images.map(\.url)
    quicklookItem = quicklookItems.first
  }

//  func quicklook(images: [ImageCollectionItemImage]) {
//    clearQuicklook()
//    setQuicklook(images: images)
//  }

  func isBookmarked(selection: ImageCollectionSidebar.Selection) -> Bool {
    return selection.isSubset(of: collection.bookmarks)
  }

  func bookmark(images: some Sequence<ImageCollectionItemImage>, value: Bool) {
    images.forEach(setter(value: value, on: \.bookmarked))
    
    collection.updateBookmarks()

    Task(priority: .medium) {
      do {
        try await collection.persist(id: id)
      } catch {
        Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar bookmark): \(error)")
      }
    }
  }

  func copy(images: [ImageCollectionItemImage], to destination: URL) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.withSecurityScope {
        try images.forEach { image in
          try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
            try image.withSecurityScope {
              try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveCopyingConflicts)
            }
          }
        }
      }
    }
  }
}
