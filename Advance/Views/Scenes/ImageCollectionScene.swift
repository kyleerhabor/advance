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
  @State private var collection = ImageCollection()

  var body: some View {
    ImageCollectionView()
      .environment(collection)
  }
}

struct ImageCollectionScene: Scene {
  @State private var manager = ImageCollectionManager()

  var body: some Scene {
    WindowGroup(for: UUID.self) { $id in
      ImageCollectionSceneView()
        .windowed()
    } defaultValue: {
      UUID()
    }
    .windowToolbarStyle(.unifiedCompact)
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
