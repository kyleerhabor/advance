//
//  ImagesSidebarItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/10/26.
//

import SwiftUI

struct ImagesSidebarItemView: View {
  let item: ImagesItemModel2

  var body: some View {
    VStack {
      ImagesItemImageView(item: self.item, image: self.item.sidebarImage, phase: self.item.sidebarImagePhase)
        .aspectRatio(self.item.sidebarAspectRatio, contentMode: .fit)
        .anchorPreference(key: ImagesVisibleItemsPreferenceKey.self, value: .bounds) { anchor in
          [ImagesVisibleItem(item: self.item, anchor: anchor)]
        }
        .overlay(alignment: .topTrailing) {
          // TODO: Figure out how to draw a white outline.
          //
          // I don't know how to do the above, so I'm using opacity to create depth as a fallback.
          Image(systemName: "bookmark.fill")
            .font(.title)
            .imageScale(.small)
            .symbolRenderingMode(.multicolor)
            .opacity(0.85)
            .shadow(radius: 0.5)
            .padding(4)
            .visible(self.item.isBookmarked)
        }

      Text(self.item.title)
        .font(.subheadline)
        .padding(EdgeInsets(vertical: 4, horizontal: 8))
        .background(.fill.tertiary, in: .rect(cornerRadius: 4))
        .help(self.item.title)
    }
  }
}
