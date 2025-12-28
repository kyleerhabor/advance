//
//  AppModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import AdvanceCore
import Combine
import Observation

enum AppModelCommandAction {
  case open, showFinder, openFinder, showSidebar, bookmark, resetWindowSize
}

enum AppModelCommandSceneID {
  case images(ImagesModel.ID), folders
}

extension AppModelCommandSceneID: Equatable {}

struct AppModelCommandScene {
  let id: AppModelCommandSceneID
  let disablesShowFinder: Bool
  let disablesOpenFinder: Bool
  let disablesShowSidebar: Bool
  let disablesBookmark: Bool
  let disablesResetWindowSize: Bool
}

struct AppModelCommand {
  let action: AppModelCommandAction
  let sceneID: AppModelCommandSceneID
}

@Observable
@MainActor
final class AppModel {
  // Swift Async Algorithms has AsyncSequence.share(bufferingPolicy:) for consuming from many tasks, but because it uses
  // AsyncSequence's Failure generic, it requires at least macOS 15.
  //
  //   'Failure' is only available in macOS 15.0 or newer
  let commandsSubject: any Subject<AppModelCommand, Never>
  let commandsPublisher: AnyPublisher<AppModelCommand, Never>
  var isImagesFileImporterPresented: Bool

  init() {
    self.commandsSubject = PassthroughSubject()
    self.commandsPublisher = commandsSubject.eraseToAnyPublisher()
    self.isImagesFileImporterPresented = false
  }

  func isShowFinderDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesShowFinder ?? true
  }

  func isOpenFinderDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesOpenFinder ?? true
  }

  func isShowSidebarDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesShowSidebar ?? true
  }

  func isBookmarkDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesBookmark ?? true
  }

  func isResetWindowSizeDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.disablesResetWindowSize ?? true
  }
}
