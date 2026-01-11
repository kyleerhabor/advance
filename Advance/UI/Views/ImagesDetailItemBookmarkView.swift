//
//  ImagesDetailItemBookmarkView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/10/26.
//

import SwiftUI

struct ImagesDetailItemBookmarkView: View {
  @Environment(ImagesModel.self) private var images
  let item: ImagesItemModel2

  var body: some View {
    Button(self.item.isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add") {
      Task {
        await self.images.bookmark(item: self.item, isBookmarked: !self.item.isBookmarked)
      }
    }
  }
}
