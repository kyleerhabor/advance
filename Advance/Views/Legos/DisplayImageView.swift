//
//  DisplayImageView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/17/24.
//

import SwiftUI

struct DisplayImageView<Content>: View where Content: View {
  @Environment(\.pixelLength) private var pixel

  private let action: DisplayView.Action
  private let content: Content

  var body: some View {
    DisplayView { size in
      // For some reason, some images in full screen mode can cause SwiftUI to believe there are more views on screen
      // than there actually are (usually the first 21). This causes all the .onAppear and .task modifiers to fire,
      // resulting in a massive memory spike (e.g. ~1.8 GB).

      let size = CGSize(
        width: size.width / pixel,
        height: size.height / pixel
      )

      await action(size)
    } content: {
      content
    }
  }

  init(action: @escaping DisplayView.Action, @ViewBuilder content: () -> Content) {
    self.action = action
    self.content = content()
  }
}
