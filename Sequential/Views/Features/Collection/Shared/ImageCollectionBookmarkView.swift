//
//  ImageCollectionBookmarkView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 11/20/23.
//

import SwiftUI

struct ImageCollectionBookmarkView: View {
  @Binding var showing: Bool

  var body: some View {
    Button {
      showing.toggle()
    } label: {
      if showing {
        Label("Bookmark", systemImage: "bookmark")
          .symbolVariant(.fill)
          .labelStyle(.titleAndIcon)
      } else {
        Label("Bookmark", systemImage: "bookmark")
      }
    }
  }
}
