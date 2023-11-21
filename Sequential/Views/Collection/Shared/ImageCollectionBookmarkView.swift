//
//  ImageCollectionBookmarkView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 11/20/23.
//

import SwiftUI

struct ImageCollectionBookmarkView: View {
  @Binding var bookmarked: Bool

  var body: some View {
    Button {
      bookmarked.toggle()
    } label: {
      if bookmarked {
        Label("Bookmark", systemImage: "bookmark")
          .symbolVariant(.fill)
          .labelStyle(.titleAndIcon)
      } else {
        Label("Bookmark", systemImage: "bookmark")
      }
    }
  }
}

#Preview {
  @State var bookmarked = false

  return ImageCollectionBookmarkView(bookmarked: $bookmarked)
}
