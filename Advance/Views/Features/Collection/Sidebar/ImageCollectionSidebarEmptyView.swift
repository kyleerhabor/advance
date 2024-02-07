//
//  ImageCollectionSidebarEmptyView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/15/23.
//

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
  @Environment(\.prerendering) private var prerendering
  @Environment(\.id) private var id
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories
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
      }.labelStyle(ImageCollectionEmptySidebarLabelStyle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      if visible {
        Color.clear
          .focusedSceneValue(\.open, .init(identity: id, enabled: true) {
            isFileImporterPresented = true
          })
          .dropDestination(for: ImageTransferable.self) { items, _ in
            Task {
              let state = await resolve(items: items, in: collection.store)
              let items = state.value

              collection.store = state.store

              items.forEach { item in
                collection.items[item.root.bookmark] = item
              }

              let ids = items.map(\.root.bookmark)

              collection.order.append(contentsOf: ids)
              collection.update()

              Task(priority: .medium) {
                do {
                  try await collection.persist(id: id)
                } catch {
                  Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar drop): \(error)")
                }
              }
            }

            return true
          }
      }
    }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image, .folder], allowsMultipleSelection: true) { result in
      switch result {
        case .success(let urls):
          Task {
            let state = await resolve(urls: urls, in: collection.store)
            let items = state.value

            collection.store = state.store

            items.forEach { item in
              collection.items[item.root.bookmark] = item
            }

            let ids = items.map(\.root.bookmark)

            collection.order.appended(ids)
            collection.update()

            Task(priority: .medium) {
              do {
                try await collection.persist(id: id)
              } catch {
                Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar button): \(error)")
              }
            }
          }
        case .failure(let err):
          Logger.ui.error("Could not import files from sidebar button: \(err)")
      }
    }
    .fileDialogOpen()
    .disabled(!visible)
  }

  static nonisolated func prepare(
    item: ImageTransferable,
    includingHiddenFiles importHidden: Bool,
    includingSubdirectories importSubdirectories: Bool
  ) -> ImageCollection.Kind {
    let url = item.url
    let source = URLSource(
      url: url,
      options: item.original ? [.withReadOnlySecurityScope, .withoutImplicitSecurityScope] : []
    )

    if item.type == .folder {
      return .document(.init(
        source: source,
        files: url.withSecurityScope {
          FileManager.default
            .contents(at: url, options: .init(includingHiddenFiles: importHidden, includingSubdirectories: importSubdirectories))
            .finderSort()
            .map { .init(url: $0, options: []) }
        }
      ))
    }

    return .file(source)
  }

  static nonisolated func resolve(
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

  static nonisolated func resolve(
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

  static nonisolated func resolve(
    items: [ImageTransferable],
    in store: BookmarkStore,
    includingHiddenFiles importHidden: Bool,
    includingSubdirectories importSubdirectories: Bool
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    // TODO: Extract this.
    let kinds = items.map { Self.prepare(item: $0, includingHiddenFiles: importHidden, includingSubdirectories: importSubdirectories) }

    return await Self.resolve(kinds: kinds, in: store)
  }

  func resolve(
    urls: [URL],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    await Self.resolve(urls: urls, in: store, includingHiddenFiles: importHidden, includingSubdirectories: importSubdirectories)
  }

  func resolve(
    items: [ImageTransferable],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<[ImageCollectionItem]> {
    await Self.resolve(items: items, in: store, includingHiddenFiles: importHidden, includingSubdirectories: importSubdirectories)
  }
}
