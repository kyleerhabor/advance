//
//  ImagesSidebarItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import IdentifiedCollections
import OSLog
import SwiftUI

struct ImagesSidebarItemCopyFolderView: View {
  @Environment(FoldersSettingsModel.self) private var folders
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @Binding var selection: Set<ImagesItemModel2.ID>
  @Binding var isFileImporterPresented: Bool
  @Binding var error: ImagesModelCopyFolderError?
  @Binding var isErrorPresented: Bool
  let items: Set<ImagesItemModel2.ID>

  var body: some View {
    Menu("Images.Item.Folder.Item.Copy") {
      ForEach(self.folders.resolved) { folder in
        ImagesItemCopyFolderOpenFolderView(folder: folder) {
          Button {
            Task {
              do {
                try await self.images.copyFolder(
                  items: self.images.items.filter(in: self.items, by: \.id),
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
      self.selection = self.items
      self.isFileImporterPresented = true
    }
  }
}
