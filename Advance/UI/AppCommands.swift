//
//  AppCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import OSLog
import SwiftUI

struct AppCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @FocusedValue(ImagesModel.self) private var images
  @FocusedValue(FoldersSettingsModel2.self) private var folders
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @State private var isImagesFileImporterPresented = false

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Section {
        Button("Commands.Open") {
          if let folders {
            folders.isFileImporterPresented = true

            return
          }

          guard let images, images.hasLoadedNoImages else {
            isImagesFileImporterPresented = true

            return
          }

          images.isFileImporterPresented = true
        }
        .keyboardShortcut(.open)
      }
      .fileImporter(
        isPresented: $isImagesFileImporterPresented,
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
    }
  }

  func openFolders(folders: FoldersSettingsModel2) {
    
  }
}
