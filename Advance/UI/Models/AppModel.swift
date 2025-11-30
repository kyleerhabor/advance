//
//  AppModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import AdvanceCore
import AsyncAlgorithms
import Observation

enum AppModelCommandAction {
  case open, showFinder, openFinder, resetWindowSize
}

enum AppModelCommandSceneID {
  case images(ImagesModel.ID), folders
}

extension AppModelCommandSceneID: Equatable {}

struct AppModelCommandScene {
  let id: AppModelCommandSceneID
  let disablesShowFinder: Bool
  let disablesOpenFinder: Bool
  let disablesResetWindowSize: Bool
}

struct AppModelCommand {
  let action: AppModelCommandAction
  let sceneID: AppModelCommandSceneID
}

@Observable
@MainActor
final class AppModel {
  let commands: AsyncChannel<AppModelCommand>
  var isImagesFileImporterPresented: Bool

  init() {
    self.commands = AsyncChannel()
    self.isImagesFileImporterPresented = false
  }

  func isShowFinderDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesShowFinder ?? true
  }

  func isOpenFinderDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesOpenFinder ?? false
  }

  func isResetWindowSizeDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesResetWindowSize ?? true
  }
}
