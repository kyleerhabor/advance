//
//  ImageCollectionSidebarView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/14/23.
//

import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  private var isEmpty: Bool {
    collection.images.isEmpty
  }

  var body: some View {
    ImageCollectionSidebarContentView()
      .overlay {
        let isEmpty = isEmpty

        Color.clear
          .visible(isEmpty)
          .animation(.default, value: isEmpty)
          .transaction(value: isEmpty, setter(on: \.disablesAnimations, value: !isEmpty))
      }
  }
}
