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
  let image: ImagesItemImageModel

  var body: some View {
    let isSuccess = self.image.phase == .success

    // For some reason, drawing the image in a Canvas reduces hangs when scrolling. rendersAsynchronously further
    // reduces this, but I've noticed that it can produce odd renderings that are immediately fixed on the next rendering.
    Canvas(opaque: self.image.isOpaque) { context, size in
      var bounds: CGSize {
        guard let device = MTLCreateSystemDefaultDevice() else {
          return size
        }

        let scaled = size.scale(max: CGFloat(device.max2DTextureSize) / context.environment.displayScale)

        return scaled
      }

      // context.opacity is writable, but doesn't seem to animate.
      //
      // FIXME: Drawing an image larger than the limit results in empty space.
      //
      // The only solutions I'm aware of (besides upgrading, of course) are to either not use Canvas (which would be
      // undesirable for performance) or tile images.
      //
      // FIXME: Image analysis doesn't consider bounds.
      context.draw(
        Image(nsImage: self.image.image),
        in: CGRect(origin: .zero, size: bounds),
      )

    }
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
