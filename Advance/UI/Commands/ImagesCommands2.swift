//
//  ImagesCommands2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/25/25.
//

import OSLog
import SwiftUI

struct ImagesCommands2: Commands {
  @Environment(\.openWindow) private var openWindow
  @FocusedValue(ImagesModel.self) private var images
  @FocusedValue(Windowed.self) private var windowed
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @State private var isFileImporterPresented = false
  private var isShowInFinderDisabled: Bool {
    guard let images else {
      return true
    }

    return images.hasInvalidSelection(forItems: images.selection)
  }

  var body: some Commands {
//    CommandGroup(after: .newItem) {
//      Section {
//        Button("Commands.Images.Open") {
//          guard let images, images.hasLoadedNoImages else {
//            isFileImporterPresented = true
//
//            return
//          }
//
//          images.isFileImporterPresented = true
//        }
//        .keyboardShortcut(.open)
//      }
//      .fileImporter(
//        isPresented: $isFileImporterPresented,
//        allowedContentTypes: imagesContentTypes,
//        allowsMultipleSelection: true,
//      ) { result in
//        let urls: [URL]
//
//        switch result {
//          case let .success(x):
//            urls = x
//          case let .failure(error):
//            // TODO: Elaborate.
//            Logger.ui.error("\(error)")
//
//            return
//        }
//
//        Task {
//          let images = ImagesModel(id: UUID())
//          await images.store(
//            urls: urls,
//            directoryEnumerationOptions: StorageKeys.directoryEnumerationOptions(
//              importHiddenFiles: importHiddenFiles,
//              importSubdirectories: importSubdirectories,
//            ),
//          )
//
//          openWindow(value: images)
//        }
//      }
//    }

    CommandGroup(after: .saveItem) {
      Section {
        Button("Finder.Item.Show", systemImage: "finder") {
          guard let images else {
            return
          }

          images.showFinder(items: images.selection)
        }
        .keyboardShortcut(.showInFinder)
        .disabled(isShowInFinderDisabled)
      }
    }

    CommandGroup(after: .windowSize) {
      Section {
        Button("Commands.Images.Window.Size.Reset") {
          windowed?.window?.setContentSize(ImagesScene.defaultSize)
        }
        .keyboardShortcut(.resetWindowSize)
        .disabled(windowed?.window == nil)
      }
    }
  }
}
