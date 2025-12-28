//
//  AppCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import OSLog
import SwiftUI

struct AppCommands: Commands {
  @Environment(AppModel.self) private var app
  @Environment(\.openWindow) private var openWindow
  @FocusedValue(\.commandScene) private var scene
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories

  var body: some Commands {
    SidebarCommands()

    CommandGroup(after: .newItem) {
      @Bindable var app = app

      Section {
        Button("Commands.Open") {
          guard let scene else {
            app.isImagesFileImporterPresented = true

            return
          }

          app.commandsSubject.send(AppModelCommand(action: .open, sceneID: scene.id))
        }
        .keyboardShortcut(.open)
      }
      .fileImporter(
        isPresented: $app.isImagesFileImporterPresented,
        allowedContentTypes: imagesContentTypes,
        allowsMultipleSelection: true,
      ) { result in
        let urls: [URL]

        switch result {
          case let .success(x):
            urls = x
          case let .failure(error):
            // TODO: Elaborate.
            Logger.ui.error("\(error)")

            return
        }

        Task {
          let images = ImagesModel(id: UUID())
          await images.store(
            urls: urls,
            directoryEnumerationOptions: StorageKeys.directoryEnumerationOptions(
              importHiddenFiles: importHiddenFiles,
              importSubdirectories: importSubdirectories,
            ),
          )

          openWindow(value: images)
        }
      }
      .fileDialogCustomizationID(ImagesScene.id)
    }

    CommandGroup(after: .saveItem) {
      Section {
        Button("Finder.Item.Show") {
          guard let scene else {
            return
          }

          app.commandsSubject.send(AppModelCommand(action: .showFinder, sceneID: scene.id))
        }
        .keyboardShortcut(.showFinder)
        .disabled(app.isShowFinderDisabled(for: scene))

        Button("Finder.Item.Open") {
          guard let scene else {
            return
          }

          app.commandsSubject.send(AppModelCommand(action: .openFinder, sceneID: scene.id))
        }
        .keyboardShortcut(.openFinder)
        .disabled(app.isOpenFinderDisabled(for: scene))
      }
    }

    CommandGroup(before: .sidebar) {
      Section {
        Button("Sidebar.Item.Show", systemImage: "sidebar.squares.leading") {
          guard let scene else {
            return
          }

          app.commandsSubject.send(AppModelCommand(action: .showSidebar, sceneID: scene.id))
        }
        .keyboardShortcut(.showSidebar)
        .disabled(app.isShowSidebarDisabled(for: scene))
      }
    }

    CommandMenu("Commands.Image") {
      Section {
        // TODO: Support conditional names.
        Button("Commands.Image.Bookmark") {
          guard let scene else {
            return
          }

          app.commandsSubject.send(AppModelCommand(action: .bookmark, sceneID: scene.id))
        }
        .keyboardShortcut(.bookmark)
        .disabled(app.isBookmarkDisabled(for: scene))
      }
    }

    CommandGroup(after: .windowSize) {
      Section {
        Button("Commands.Window.Size.Reset") {
          guard let scene else {
            return
          }

          app.commandsSubject.send(AppModelCommand(action: .resetWindowSize, sceneID: scene.id))
        }
        .keyboardShortcut(.resetWindowSize)
        .disabled(app.isResetWindowSizeDisabled(for: scene))
      }
    }
  }
}
