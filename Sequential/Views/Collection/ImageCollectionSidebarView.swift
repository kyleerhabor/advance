//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.loaded) private var loaded
  private var visible: Bool {
    loaded && collection.images.isEmpty
  }

  var body: some View {
    ImageCollectionSidebarContentView()
      .overlay {
        ImageCollectionSidebarEmptyView()
          .visible(visible)
          .animation(.default, value: visible)
          .transaction(value: visible, setter(value: !visible, on: \.disablesAnimations))
      }
  }
}
