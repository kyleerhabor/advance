//
//  ImageCollectionScene.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import SwiftUI

struct ImageCollectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(ImageCollection())
}

extension EnvironmentValues {
  var collection: ImageCollectionEnvironmentKey.Value {
    get { self[ImageCollectionEnvironmentKey.self] }
    set { self[ImageCollectionEnvironmentKey.self] = newValue }
  }
}

struct ImageCollectionScene: Scene {
  var body: some Scene {
    WindowGroup(for: ImageCollection.self) { collection in
      ImageCollectionView()
        .environment(\.collection, collection)
        .windowed()
    } defaultValue: {
      .init()
    }
    .windowToolbarStyle(.unifiedCompact)
    .commands {
      // The reason this is separated into its own struct is not for prettiness, but rather so changes to focus don't
      // re-evaluate the whole scene (which makes clicking when there are a lot of images not slow).
      ImageCollectionCommands()
    }
  }
}
