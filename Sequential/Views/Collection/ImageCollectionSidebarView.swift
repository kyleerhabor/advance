//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.collection) private var collection
  @Environment(\.prerendering) private var prerendering

  let scrollDetail: Scroller.Scroll

  var body: some View {
    ImageCollectionSidebarContentView(scrollDetail: scrollDetail)
      .overlay {
        let visible = collection.wrappedValue.items.isEmpty && !prerendering

        VStack {
          if visible {
            ImageCollectionSidebarEmptyView()
          }
        }
        .visible(visible)
        .animation(.default, value: visible)
      }
  }
}
