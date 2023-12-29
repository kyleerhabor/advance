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

  var body: some View {
    ImageCollectionView()
      .environment(collection)
      // The pre-rendering variable triggers SwiftUI to call the action with an up-to-date id when performing scene
      // restoration. It's weird we can't just bind id.
      .task(id: prerendering) {
        let collection: ImageCollection

        if let coll = manager.collections[id] {
          Logger.model.info("Fetched image collection \"\(id)\" from manager")

          collection = coll
        } else {
          let url = URL.collectionFile(for: id)

          do {
            collection = try await fetch(from: url)

            Logger.model.info("Fetched image collection \"\(id)\" from file at URL \"\(url.string)\"")
          } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
            Logger.model.info("Could not fetch image collection \"\(id)\" as its file at URL \"\(url.string)\" does not exist")

            return
          } catch {
            Logger.model.error("Could not fetch image collection \"\(id)\": \(error)")

            return
          }
        }

        self.collection = collection
      }.onDisappear {
        manager.collections[id] = nil
      }
  }

  func fetch(from url: URL) async throws -> ImageCollection {
    let data = try Data(contentsOf: url)
    let decoder = PropertyListDecoder()
    let decoded = try decoder.decode(ImageCollection.self, from: data)

    return decoded
  }
}

struct ImageCollectionScene: Scene {
  @State private var manager = ImageCollectionManager()

  var body: some Scene {
    WindowGroup(for: UUID.self) { $id in
      ImageCollectionSceneView()
        .environment(\.id, id)
        .windowed()
    } defaultValue: {
      .init()
    }
    .windowToolbarStyle(.unifiedCompact)
    .commands {
      // The reason this is separated into its own struct is not for prettiness, but rather so changes to focus don't
      // re-evaluate the whole scene (which makes clicking when there are a lot of images not slow).
      ImageCollectionCommands()
    }.environment(manager)
  }
}
