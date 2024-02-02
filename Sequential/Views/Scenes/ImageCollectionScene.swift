//
//  ImageCollectionScene.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import OSLog
import SwiftUI

struct ImageCollectionSceneView: View {
  @Environment(ImageCollectionManager.self) private var manager
  @Environment(\.prerendering) private var prerendering
  @Environment(\.id) private var id
  @State private var collection = ImageCollection()
  @State private var loaded = false

  var body: some View {
    ImageCollectionView()
      .environment(collection)
      .environment(\.loaded, loaded)
      // The pre-rendering variable triggers SwiftUI to call the action with an up-to-date id when performing scene
      // restoration. It's weird we can't just bind id.
      .task(id: prerendering) {
        loaded = false

        defer {
          loaded = true
        }

        manager.ids.insert(id)

        let collection: ImageCollection

        if let coll = manager.collections[id] {
          Logger.model.info("Fetched image collection \"\(id)\" from manager")

          collection = coll
        } else {
          let url = URL.collectionFile(for: id)

          do {
            collection = try await Self.fetch(from: url)

            Logger.model.info("Fetched image collection \"\(id)\" from file at URL \"\(url.string)\"")
          } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
            Logger.model.info("Could not fetch image collection \"\(id)\" as its file at URL \"\(url.string)\" does not exist")

            return
          } catch {
            Logger.model.error("Could not fetch image collection \"\(id)\": \(error)")

            return
          }
        }

        await Self.resolve(collection: collection)

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

  // Be careful here: we're asynchronously mutating variables on the image collection. The reason (I believe) it's safe
  // to do so here is because, from our usage in task(id:_:), the collection isn't being used elsewhere.
  static func resolve(collection: ImageCollection) async {
    let roots = collection.items.values.map(\.root)
    let state = await Self.resolve(roots: roots, in: collection.store)
    let items = collection.order.compactMap { id -> ImageCollectionItem? in
      guard let root = collection.items[id]?.root,
            let image = state.value[id] else {
        return nil
      }

      return .init(root: root, image: image)
    }

    collection.store = state.store

    items.forEach { item in
      collection.items[item.root.bookmark] = item
    }

    collection.order = .init(items.map(\.root.bookmark))
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
        .environment(\.id, id)
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
    .deferred(count: 2) {
      Task(priority: .background) {
        await initialize()
      }
    }
  }

  func initialize() async {
    let directory = URL.collectionDirectory
    let collections: [URL]

    do {
      collections = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [])
    } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
      // The directory does not exist, so we don't care.
      return
    } catch {
      Logger.standard.error("Could not read contents of collections directory \"\(directory.string)\": \(error)")

      return
    }

    collections.forEach { url in
      do {
        try FileManager.default.removeItem(at: url)
      } catch {
        Logger.standard.error("Could not delete collection at URL \"\(url.string)\": \(error)")
      }
    }
  }
}
