//
//  AppModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import AdvanceCore
import Combine
import Foundation
import Observation

enum AppModelCommandAction {
  case open, showFinder, openFinder, showSidebar, bookmark, toggleLiveTextIcon, toggleLiveTextHighlight, resetWindowSize
}

enum AppModelCommandSceneID {
  case images(ImagesModel.ID),
       imagesSidebar(ImagesModel.ID),
       folders
}

extension AppModelCommandSceneID: Equatable {}

struct AppModelActionCommand {
  let isDisabled: Bool
}

extension AppModelActionCommand: Equatable {}

struct AppModelToggleCommand {
  let isDisabled: Bool
  let isOn: Bool
}

extension AppModelToggleCommand: Equatable {}

struct AppModelCommandScene {
  let id: AppModelCommandSceneID
  let showFinder: AppModelActionCommand
  let openFinder: AppModelActionCommand
  let showSidebar: AppModelActionCommand
  let bookmark: AppModelToggleCommand
  let liveTextIcon: AppModelToggleCommand
  let liveTextHighlight: AppModelToggleCommand
  let resetWindowSize: AppModelActionCommand
}

extension AppModelCommandScene: Equatable {}

struct AppModelCommand {
  let action: AppModelCommandAction
  let sceneID: AppModelCommandSceneID
}

@Observable
@MainActor
final class AppModel {
  // Swift Async Algorithms has AsyncSequence/share(bufferingPolicy:) for consuming from many tasks, but because it uses
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
    scene?.showFinder.isDisabled ?? true
  }

  func isOpenFinderDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.openFinder.isDisabled ?? true
  }

  func isShowSidebarDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.showSidebar.isDisabled ?? true
  }

  func isBookmarkDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.bookmark.isDisabled ?? true
  }

  func isBookmarkOn(for scene: AppModelCommandScene?) -> Bool {
    scene?.bookmark.isOn ?? false
  }

  func isLiveTextIconDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.liveTextIcon.isDisabled ?? true
  }

  func isLiveTextIconOn(for scene: AppModelCommandScene?) -> Bool {
    scene?.liveTextIcon.isOn ?? false
  }

  func isLiveTextHighlightDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.liveTextHighlight.isDisabled ?? true
  }

  func isLiveTextHighlightOn(for scene: AppModelCommandScene?) -> Bool {
    scene?.liveTextHighlight.isOn ?? false
  }

  func isResetWindowSizeDisabled(for scene: AppModelCommandScene?) -> Bool {
    scene?.resetWindowSize.isDisabled ?? true
  }
}
