//
//  ImageCollectionScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Algorithms
import OSLog
import SwiftUI

struct ImageCollectionSceneView: View {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(\.imagesID) private var id
  @State private var collection = ImageCollection()

  var body: some View {
    ImageCollectionView()
      .environment(collection)
      // The pre-rendering variable triggers SwiftUI to call the action with an up-to-date id when performing scene
      // restoration. It's weird we can't just bind id.
      .task/*(id: isPrerendering)*/ {
        manager.ids.insert(id)

        let collection: ImageCollection

        if let coll = manager.collections[id] {
          Logger.model.info("Fetched image collection \"\(id)\" from manager")

          collection = coll
        } else {
          let url = URL.collectionFile(for: id)

          do {
            collection = try await Self.fetch(from: url)

            Logger.model.info("Fetched image collection \"\(id)\" from file at URL \"\(url.pathString)\"")
          } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
            Logger.model.info("Could not fetch image collection \"\(id)\" as its file at URL \"\(url.pathString)\" does not exist")

            return
          } catch {
            Logger.model.error("Could not fetch image collection \"\(id)\": \(error)")

            return
          }
        }

        let state = await Self.resolve(collection: collection)

        collection.store = state.store

        state.value.forEach { item in
          collection.items[item.root.bookmark] = item
        }

        collection.order = .init(state.value.map(\.root.bookmark))
        collection.update()

        Task(priority: .medium) {
          do {
            try await collection.persist(id: id)
          } catch {
            Logger.model.error("Could not persist image collection \"\(id)\" from initialization: \(error)")
          }
        }

        self.collection = collection
      }.onDisappear {
        manager.collections[id] = nil
      }
  }

  static func fetch(from url: URL) async throws -> ImageCollection {
    let data = try Data(contentsOf: url)
    let decoder = PropertyListDecoder()
    let decoded = try decoder.decode(ImageCollection.self, from: data)

    return decoded
  }

  static func resolve(
    roots: [ImageCollectionItemRoot],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<ImageCollection.Images> {
    let bookmarks = roots.compactMap { store.bookmarks[$0.bookmark] }

    let books = await ImageCollection.resolving(bookmarks: bookmarks, in: store)
    let roots = roots.filter { books.value.contains($0.bookmark) }

    let images = await ImageCollection.resolve(roots: roots, in: books.store)

    return .init(store: books.store, value: images)
  }

  static func collect(collection: ImageCollection, images: ImageCollection.Images) -> [ImageCollectionItem] {
    collection.order.compactMap { id in
      guard let root = collection.items[id]?.root,
            let image = images[id] else {
        return nil
      }

      return .init(root: root, image: image)
    }
  }

  // MARK: Convenience (concurrency)
  static func resolve(collection: ImageCollection) async -> BookmarkStoreState<[ImageCollectionItem]> {
    // FIXME: Swift sometimes crashes accessing the count of the collection.
    //
    // TODO: Decouple SwiftUI models from underlying data.
    let roots = collection.items.values.map(\.root)
    let state = await Self.resolve(roots: roots, in: collection.store)
    let items = Self.collect(collection: collection, images: state.value)

    return .init(store: state.store, value: items)
  }
}

struct ImageCollectionScene: Scene {
  @State private var manager = ImageCollectionManager()

  // This is the default size used by SwiftUI. I'm using it since I think it looks nice, but the constant is here for
  // de-duplication and safeguarding from the future.
  static let defaultSize = CGSize(width: 900, height: 450)

  var body: some Scene {
    WindowGroup(for: UUID.self) { $id in
      ImageCollectionSceneView()
        .environment(\.imagesID, id)
        .windowed()
    } defaultValue: {
      .init()
    }
    .windowToolbarStyle(.unifiedCompact)
    .defaultSize(Self.defaultSize)
    .commands {
      // This is given its own struct so focus states don't re-evaluate the whole scene.
      ImageCollectionCommands()
    }
    .environment(manager)
    // It seems delaying the action to the next cycle in SwiftUI creates enough time for the task in ImageCollectionSceneView
    // to collect all the collection IDs before initialize(allowing:) gets called. Personally, I wonder if this may
    // result in a rare race condition where the view does not report its ID in time and tries reading from a file
    // that's about to be deleted.
    //
    // Maybe increase to 2 just to be safe?
    .deferred(count: 1) {
      Task(priority: .background) {
        await Self.initialize(allowing: manager.ids)
      }
    }
  }

  static func initialize(allowing ids: Set<UUID>) async {
    let directory = URL.collectionDirectory
    let collections: [URL]

    do {
      collections = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [])
    } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
      // The directory does not exist, so we don't care.
      return
    } catch {
      Logger.ui.error("Could not read contents of collections directory \"\(directory.path)\": \(error)")

      return
    }

    collections
      .map { url -> Pair<URL, UUID>? in
        guard let id = UUID(uuidString: url.lastPath) else {
          return nil
        }

        return Pair(left: url, right: id)
      }
      .compacted()
      .filter { !ids.contains($0.right) }
      .forEach { pair in
        let url = pair.left

        do {
          try FileManager.default.removeItem(at: url)
        } catch {
          Logger.ui.error("Could not delete collection at URL \"\(url.pathString)\": \(error)")
        }
      }
  }
}
