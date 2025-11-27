//
//  FoldersSettingsView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

let foldersContentTypes = [UTType.folder]

struct FoldersSettingsView2: View {
  @Environment(FoldersSettingsModel2.self) private var folders

  var body: some View {
    List(folders.items) { item in
      Label {
        // TODO
      } icon: {
        // TODO
      }
    }
    .listStyle(.inset)
    .toolbar {
      @Bindable var folders = folders

      Button("Add...", systemImage: "plus") {
        folders.isFileImporterPresented = true
      }
      .fileImporter(
        isPresented: $folders.isFileImporterPresented,
        allowedContentTypes: foldersContentTypes,
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
          await folders.store(urls: urls)
        }
      }
    }
    .task {
      await folders.load()
    }
  }
}
