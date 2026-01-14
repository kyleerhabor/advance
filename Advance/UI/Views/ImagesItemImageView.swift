//
//  ImagesItemImageView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/2/26.
//

import SwiftUI

struct ImagesItemImageView: View {
  @State private var hasElapsed = false
  // For some reason, storing an NSImage directly results in a memory leak. I presume that passing it to the initializer
  // binds the view's lifetime to it, rather than the individual views.
  let image: ImagesItemModelImage

  var body: some View {
    let isSuccess = self.image.phase == .success

    Image(nsImage: self.image.image)
      .resizable()
      .visible(isSuccess)
      .background(.fill.quaternary.visible(!isSuccess), in: .rect)
      .animation(.default, value: isSuccess)
      .overlay {
        let isVisible = self.image.phase == .empty && self.hasElapsed

        ProgressView()
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .overlay {
        let isVisible = self.image.phase == .failure

        Image(systemName: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .imageScale(.large)
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .aspectRatio(self.image.aspectRatio, contentMode: .fit)
      .task {
        do {
          try await Task.sleep(for: .imagesElapse)
        } catch is CancellationError {
          return
        } catch {
          unreachable()
        }

        self.hasElapsed = true
      }
  }
}
