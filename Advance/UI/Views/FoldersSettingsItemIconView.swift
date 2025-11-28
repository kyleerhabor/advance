//
//  FoldersSettingsItemIconView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import SwiftUI

struct FoldersSettingsItemIconView: View {
  let item: FoldersSettingsItemModel

  var body: some View {
    image.resizable()
  }

  var image: Image {
    if item.isResolved {
      Image(nsImage: item.icon)
    } else {
      // symbolRenderingMode(_:) doesn't work on NSImage.init(systemSymbolName:accessibilityDescription:)
      Image(systemName: "questionmark.folder.fill")
    }
  }
}
