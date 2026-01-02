//
//  ImageCollectionSidebarContentView.swift
//  Advance
//
//  Created by Kyle Erhabor on 10/11/23.
//

import Defaults
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

struct ImageCollectionSidebarContentView: View {
  typealias VisibleImageIDsPreferenceKey = VisiblePreferenceKey<ImageCollectionItemImage.ID>

  @Environment(ImageCollection.self) private var collection
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(\.imagesID) private var id

  var body: some View {
    ScrollViewReader { proxy in
      @Bindable var sidebar = self.sidebar

      List(selection: $sidebar.selection) {
        ForEach(sidebar.images) { image in
          let size = image.properties.orientedSize

          ImageCollectionItemImageView()
            .aspectRatio(size.width / size.height, contentMode: .fit)
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
//    .fileDialogCopy()
  }

  func images(from selection: ImageCollectionSidebar.Selection) -> [ImageCollectionItemImage] {
    collection.images.filter(in: selection, by: \.id)
  }

  func urls(from selection: ImageCollectionSidebar.Selection) -> [URL] {
    images(from: selection).map(\.url)
  }
}
