//
//  ImageCollectionSidebarView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/14/23.
//

import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.loaded) private var loaded
  private var isEmpty: Bool {
    loaded && collection.images.isEmpty
  }

  var body: some View {
    ImageCollectionSidebarContentView()
      .overlay {
        let empty = isEmpty

        ImageCollectionSidebarEmptyView(visible: empty)
          .visible(empty)
          .animation(.default, value: empty)
          .transaction(value: empty, setter(value: !empty, on: \.disablesAnimations))
      }
  }
}
