//
//  ImagesItemCopyFolderOpenFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/17/25.
//

import SwiftUI

struct ImagesItemCopyFolderOpenFolderView<Content>: View where Content: View {
  @Environment(FoldersSettingsModel.self) private var folders
  private let folder: FoldersSettingsItemModel
  private let content: Content

  var body: some View {
    // We need this VStack to prevent ForEach from taking its slow path:
    //
    //   Unable to determine number of views per element in the collection [...]. If this view only produces one view
    //   per element in the collection, consider wrapping your views in a VStack to take the fast path.
    VStack {
      if #unavailable(macOS 15) {
        self.content
      } else {
        self.content
          .modifierKeyAlternate(.option) {
            Button("Finder.Item.\(self.folder.path).Open") {
              Task {
                await self.folders.openFinder(item: self.folder)
              }
            }
            .help(Text("Finder.Item.\(self.folder.helpPath).Open"))
          }
      }
    }
  }

  init(folder: FoldersSettingsItemModel, @ViewBuilder content: () -> Content) {
    self.folder = folder
    self.content = content()
  }
}
