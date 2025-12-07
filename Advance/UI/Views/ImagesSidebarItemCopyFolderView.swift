//
//  ImagesSidebarItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import OSLog
import SwiftUI

struct ImagesSidebarItemCopyFolderView: View {
  @Environment(FoldersSettingsModel.self) private var folders
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @Binding var selection: Set<ImagesItemModel2.ID>
  @Binding var isFileImporterPresented: Bool
  @Binding var error: ImagesModelCopyFolderError?
  @Binding var isErrorPresented: Bool
  let items: Set<ImagesItemModel2.ID>

  var body: some View {
    Menu("Images.Item.Folder.Copy") {
      ForEach(folders.resolved) { item in
        Button {
          Task {
            do {
              try await images.copyFolder(
                items: items,
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
        .transform { content in
          if #unavailable(macOS 15) {
            content
          } else {
            content
              .modifierKeyAlternate(.option) {
                Button("Finder.Item.\(item.path).Open") {
                  Task {
                    await folders.openFinder(item: item)
                  }
                }
              }
          }
        }
      }
    } primaryAction: {
      selection = items
      isFileImporterPresented = true
    }
  }
}
