//
//  ImageCollectionSidebarEmptyView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/15/23.
//

import AdvanceCore
import Defaults
import OSLog
import SwiftUI

struct ImageCollectionEmptySidebarLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 8) {
      configuration.icon
        .symbolRenderingMode(.hierarchical)

      configuration.title
        .font(.subheadline)
        .fontWeight(.medium)
    }
  }
}

struct ImageCollectionSidebarEmptyView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.imagesID) private var id
  @State private var isFileImporterPresented = false

  let visible: Bool

  var body: some View {
    Button {
      isFileImporterPresented = true
    } label: {
      Label {
        Text("Images.Sidebar.Import")
      } icon: {
        Image(systemName: "square.and.arrow.down")
          .resizable()
          .scaledToFit()
          .frame(width: 24)
      }
      .labelStyle(ImageCollectionEmptySidebarLabelStyle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .disabled(!visible)
  }

  nonisolated static func resolve(
    kinds: [ImageCollection.Kind],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    let rooted = await ImageCollection.resolve(kinds: kinds, in: store)
    let values = rooted.value.values
    let bookmarks = values.compactMap { rooted.store.bookmarks[$0.bookmark] }

    let books = await ImageCollection.resolving(bookmarks: bookmarks, in: rooted.store)
    let vals = values.filter { books.value.contains($0.bookmark) }

    let images = await ImageCollection.resolve(roots: vals, in: books.store)
    let items = kinds.flatMap { kind in
      kind.files.compactMap { source -> ImageCollectionItem? in
        guard let root = rooted.value[source.url],
              let image = images[root.bookmark] else {
          return nil
        }

        return .init(root: root, image: image)
      }
    }

    return .init(store: books.store, value: items)
  }

  // MARK: - Convenience (concurrency)

  nonisolated static func resolve(
    urls: [URL],
    in store: BookmarkStore,
    includingHiddenFiles importHidden: Bool,
    includingSubdirectories importSubdirectories: Bool
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    let kinds = urls.map { url in
      ImageCollection.prepare(
        url: url,
        includingHiddenFiles: importHidden,
        includingSubdirectories: importSubdirectories
      )
    }

    return await Self.resolve(kinds: kinds, in: store)
  }

  func resolve(
    urls: [URL],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    await Self.resolve(urls: urls, in: store, includingHiddenFiles: false, includingSubdirectories: true)
  }
}
