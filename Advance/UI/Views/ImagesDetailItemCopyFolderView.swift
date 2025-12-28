//
//  ImagesDetailItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/16/25.
//

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
      ForEach(folders.resolved) { item in
        ImagesItemCopyFolderOpenFolderView(item: item) {
          Button {
            Task {
              do {
                try await images.copyFolder(
                  item: self.item,
                  to: item,
                  locale: locale,
                  resolveConflicts: resolveConflicts,
                  pathSeparator: foldersPathSeparator,
                  pathDirection: foldersPathDirection,
                )
              } catch let error as ImagesModelCopyFolderError {
                self.error = error
                self.isErrorPresented = true
              }
            }
          } label: {
            Text(item.path)
          }
        }
      }
    } primaryAction: {
      selection = item
      isFileImporterPresented = true
    }
  }
}
