//
//  ImagesItemCopyFolderOpenFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/17/25.
//

import SwiftUI

struct ImagesItemCopyFolderOpenFolderView<Content>: View where Content: View {
  @Environment(FoldersSettingsModel.self) private var folders
  let item: FoldersSettingsItemModel
  let content: Content

  var body: some View {
    if #unavailable(macOS 15) {
      content
    } else {
      content
        .modifierKeyAlternate(.option) {
          Button("Finder.Item.\(item.path).Open") {
            Task {
              await folders.openFinder(item: item.id)
            }
          }
        }
    }
  }

  init(item: FoldersSettingsItemModel, @ViewBuilder content: () -> Content) {
    self.item = item
    self.content = content()
  }
}
