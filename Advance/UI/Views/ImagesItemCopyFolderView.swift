//
//  ImagesItemCopyFolderView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/26/26.
//

import SwiftUI

struct ImagesItemCopyFolderView: View {
  let folder: FoldersSettingsItemModel
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Text(self.folder.path)
        .help(Text(self.folder.helpPath))
    }
  }
}
