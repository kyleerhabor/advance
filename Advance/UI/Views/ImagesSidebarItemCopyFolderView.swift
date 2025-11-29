//
//  ImagesSidebarItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//


import OSLog
import SwiftUI

struct ImagesSidebarItemCopyFolderView: View {
  @Environment(FoldersSettingsModel2.self) private var folders
  @Environment(ImagesModel.self) private var images
  @Binding var isFileImporterPresented: Bool
  let selection: Set<ImagesItemModel2.ID>

  var body: some View {
    Menu("Images.Item.Folder.Copy") {
      ForEach(folders.resolved) { item in
        Button {
          Task {
            await folders.copy(to: item, items: selection)
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
