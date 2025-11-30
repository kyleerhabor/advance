//
//  ImagesSidebarItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesSidebarItemCopyFolderView: View {
  @Environment(FoldersSettingsModel2.self) private var folders
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @Environment(\.locale) private var locale
  @Binding var isFileImporterPresented: Bool
  @Binding var error: FoldersSettingsModelCopyError?
  @Binding var isErrorPresented: Bool
  let selection: Set<ImagesItemModel2.ID>

  var body: some View {
    Menu("Images.Item.Folder.Copy") {
      ForEach(folders.resolved) { item in
        Button {
          Task {
            do {
              try await folders.copy(
                to: item,
                items: selection,
                locale: locale,
                resolveConflicts: resolveConflicts,
                pathSeparator: foldersPathSeparator,
                pathDirection: foldersPathDirection,
              )
            } catch let error as FoldersSettingsModelCopyError {
              self.error = error
              self.isErrorPresented = true
            } catch {
              unreachable()
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
                  folders.openFinder(item: item)
                }
              }
          }
        }
      }
    } primaryAction: {
      isFileImporterPresented = true
    }
  }
}
