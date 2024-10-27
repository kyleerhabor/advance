//
//  ImagesBookmarkView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/30/24.
//

import SwiftUI

struct ImagesBookmarkView: View {
  @Binding var isBookmarked: Bool

  var body: some View {
    Button {
      isBookmarked.toggle()
    } label: {
      if isBookmarked {
        // Toggle indents the menu item list by the width of the symbol. This creates a kind of "jank" between states.
        // Instead, this conditional label treats the icon as part of the menu item's title.
        //
        // And yes, we need this conditional because labelStyle(_:) does not have a type-erased style to toggle between.
        Label {
          title
        } icon: {
          Image(systemName: "bookmark.fill")
        }
        .labelStyle(.titleAndIcon)
      } else {
        title
      }
    }
  }

  var title: some View {
    Text("Bookmark")
  }
}
