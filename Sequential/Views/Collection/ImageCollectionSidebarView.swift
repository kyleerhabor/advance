//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.prerendering) private var prerendering
  private var visible: Bool {
    !prerendering && collection.order.isEmpty
  }

  let scrollDetail: Scroller.Scroll

  var body: some View {
    ImageCollectionSidebarContentView(scrollDetail: scrollDetail)
      .overlay {
        ImageCollectionSidebarEmptyView()
          .visible(visible)
          .animation(.default, value: visible)
          .transaction(value: visible) { transaction in
            transaction.disablesAnimations = !visible
          }
      }
  }
}
