//
//  ImagesScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/18/24.
//

import AdvanceCore
import Combine
import SwiftUI
import OSLog

struct ImagesScene: Scene {
  static let defaultSize = CGSize(width: 900, height: 450)

  var body: some Scene {
    WindowGroup(for: ImagesModel.self) { $images in
      ImagesSceneView2()
        .environment(images)
        .windowed()
    } defaultValue: {
      ImagesModel(id: UUID())
    }
    .windowToolbarStyle(.unifiedCompact)
    .defaultSize(Self.defaultSize)
    .commands {
      ImagesCommands2()
    }
  }
}
