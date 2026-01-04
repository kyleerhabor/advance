//
//  AppCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import AsyncAlgorithms
import Combine
import OSLog
import SwiftUI

struct AppCommands: Commands {
  @Environment(AppModel.self) private var app
  @Environment(AppDelegate.self) private var delegate
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @FocusedValue(\.commandScene) private var scene
  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: self.importHiddenFiles,
      importSubdirectories: self.importSubdirectories,
    )
  }

  var body: some Commands {
    SidebarCommands()
    ToolbarCommands()

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
          await images.store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
          openWindow(value: images)
        }
      }
      .fileDialogCustomizationID(ImagesScene.id)
      .task {
        for await urls in delegate.openChannel {
          let images = ImagesModel(id: UUID())
          await images.store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
          openWindow(value: images)
        }
      }
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
        @Bindable var app = self.app

        Toggle(
          app.isBookmarked ? "Commands.Image.Bookmark.Remove" : "Commands.Image.Bookmark.Add",
          systemImage: "bookmark",
          isOn: $app.isBookmarked,
        )
        .keyboardShortcut(.bookmark)
        .disabled(app.isBookmarkDisabled(for: scene))
      }

      Section {
        @Bindable var app = self.app

        Toggle(
          app.isSupplementaryInterfaceVisible ? "Commands.Image.LiveTextIcon.Hide" : "Commands.Image.LiveTextIcon.Show",
          systemImage: "text.viewfinder",
          isOn: $app.isSupplementaryInterfaceVisible,
        )
        .keyboardShortcut(.toggleLiveTextIcon)
        .disabled(app.isLiveTextIconDisabled(for: scene))

        Toggle(
          app.isSelectableItemsHighlighted
            ? "Commands.Image.LiveTextHighlight.Hide"
            : "Commands.Image.LiveTextHighlight.Show",
          isOn: $app.isSelectableItemsHighlighted,
        )
        .keyboardShortcut(.toggleLiveTextHighlight)
        .disabled(app.isLiveTextHighlightDisabled(for: scene))
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
