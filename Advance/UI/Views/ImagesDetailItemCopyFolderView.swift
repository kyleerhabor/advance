//
//  ImagesDetailItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/16/25.
//

import IdentifiedCollections
import SwiftUI

struct ImagesDetailItemCopyFolderView: View {
  @Environment(\.locale) private var locale
  @Environment(ImagesModel.self) private var images
  @Environment(FoldersSettingsModel.self) private var folders
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @Binding var selection: ImagesItemModel2.ID?
  @Binding var isFileImporterPresented: Bool
  @Binding var error: ImagesModelCopyFolderError?
  @Binding var isErrorPresented: Bool
  let item: ImagesItemModel2.ID

  var body: some View {
    Menu("Images.Item.Folder.Item.Copy") {
      ForEach(self.folders.resolved) { folder in
        ImagesItemCopyFolderOpenFolderView(folder: folder) {
          Button {
            guard let item = self.images.items[id: self.item] else {
              return
            }

            Task {
              do {
                try await self.images.copyFolder(
                  item: item,
                  to: folder,
                  locale: self.locale,
                  resolveConflicts: self.resolveConflicts,
                  pathDirection: self.foldersPathDirection,
                  pathSeparator: self.foldersPathSeparator,
                )
              } catch let error as ImagesModelCopyFolderError {
                self.error = error
                self.isErrorPresented = true
              }
            }
          } label: {
            Text(folder.path)
          }
        }
      }
    } primaryAction: {
      self.selection = self.item
      self.isFileImporterPresented = true
    }
  }
}
