//
//  ImagesSidebarView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import SwiftUI

struct ImagesSidebarView: View {
  @Environment(ImagesModel.self) private var images
  var isEmpty: Bool {
    images.isReady && images.items2.isEmpty
  }

  var body: some View {
    Color.clear
      .overlay {
        let isEmpty = isEmpty

        Color.clear
          .visible(isEmpty)
          .animation(.default, value: isEmpty)
          .transaction(value: isEmpty, setter(on: \.disablesAnimations, value: !isEmpty))
      }
  }
}
