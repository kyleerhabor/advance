//
//  ImageCollectionSidebarContentView.swift
//  Advance
//
//  Created by Kyle Erhabor on 10/11/23.
//

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

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
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
    }
  }
}

struct ImageCollectionSidebarContentView: View {
  typealias VisibleImageIDsPreferenceKey = VisiblePreferenceKey<ImageCollectionItemImage.ID>

  @Environment(ImageCollection.self) private var collection
  @Environment(ImageCollectionSidebar.self) private var sidebar

  var body: some View {
    ScrollViewReader { proxy in
      @Bindable var sidebar = self.sidebar

      List(selection: $sidebar.selection) {
        ForEach(sidebar.images) { image in
          Color.clear
            .scaledToFit()
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
//      .onChange(of: collection.sidebarPage) {
//
//      }
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
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 0) {
        Divider()

        ImageCollectionSidebarFilterView()
          .padding(8)
      }
    }
    .fileDialogCopy()
  }
}
