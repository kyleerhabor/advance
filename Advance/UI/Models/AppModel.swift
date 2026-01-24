//
//  AppModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import Combine
import Observation

enum AppModelCommandAction {
  case open, showFinder, openFinder, showSidebar, toggleSidebarBookmarks, bookmark, /*toggleLiveTextIcon,*/
       toggleLiveTextHighlight, resetWindowSize
}

enum AppModelCommandSceneID {
  // I would prefer to compare ImagesModel, but that results in a memory leak. I presume that it's illegal to escape
  // data from a data-presenting window group.
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
  let sidebarBookmarks: AppModelToggleCommand
  let bookmark: AppModelToggleCommand
//  let liveTextIcon: AppModelToggleCommand
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

  func isDisabled(action: AppModelActionCommand?) -> Bool {
    action?.isDisabled ?? true
  }

  func isDisabled(toggle: AppModelToggleCommand?) -> Bool {
    toggle?.isDisabled ?? true
  }

  func isOn(toggle: AppModelToggleCommand?) -> Bool {
    toggle?.isOn ?? false
  }
}
