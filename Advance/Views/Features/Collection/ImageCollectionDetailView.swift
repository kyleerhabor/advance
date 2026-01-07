//
//  ImageCollectionDetailView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Combine
import SwiftUI

struct ImageCollectionDetailItemView: View {
  let image: ImageCollectionItemImage

  var body: some View {
    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {}
      .fileDialogCopy()
  }
}

struct ImageCollectionDetailView: View {
  let items: [ImageCollectionDetailItem]

  var body: some View {
    List(items) { item in
      // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
      ImageCollectionDetailItemView(image: item.image)
    }
    .listStyle(.plain)
  }
}
