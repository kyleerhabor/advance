//
//  ImageCollectionCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/18/23.
//

import SwiftUI

struct ImageCollectionCommands: Commands {
  var body: some Commands {
    ToolbarCommands()
    SidebarCommands()

    ImageCollectionNewCommands()
    ImageCollectionExternalCommands()
    ImageCollectionEditCommands()

    CommandGroup(after: .sidebar) {
      // The "Enter/Exit Full Screen" item is usually in its own space.
      Divider()
    }

    ImageCollectionImageCommands()
    ImageCollectionWindowCommands()
  }

  static func resolve(kinds: [ImageCollection.Kind], in store: BookmarkStore) async -> ImageCollection {
    let state = await ImageCollection.resolve(kinds: kinds, in: store)
    let order = kinds.flatMap { kind in
      kind.files.compactMap { source in
        state.value[source.url]?.bookmark
      }
    }

    let items = Dictionary(uniqueKeysWithValues: state.value.map { pair in
      (pair.value.bookmark, ImageCollectionItem(root: pair.value, image: nil))
    })

    let collection = ImageCollection(
      store: state.store,
      items: items,
      order: .init(order)
    )

    return collection
  }

  // MARK: - Convenience (concurrency)

  static func resolve(
    urls: [URL],
    in store: BookmarkStore,
    includingHiddenFiles importHidden: Bool,
    includingSubdirectories importSubdirectories: Bool
  ) async -> ImageCollection {
    let kinds = urls.map { url in
      ImageCollection.prepare(
        url: url,
        includingHiddenFiles: importHidden,
        includingSubdirectories: importSubdirectories
      )
    }

    return await Self.resolve(kinds: kinds, in: store)
  }
}
