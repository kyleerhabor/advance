//
//  ImagesItemImageView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/2/26.
//

import AdvanceCore
import SwiftUI

struct ImagesItemImageView: View {
  @State private var hasElapsed = false
  let item: ImagesItemModel2
  let aspectRatio: CGFloat
  let image: NSImage
  let phase: ImagesItemModelImagePhase

  var body: some View {
    let isSuccess = phase == .success

    Image(nsImage: image)
      .resizable()
      .background(.fill.quaternary.visible(!isSuccess), in: .rect)
      .animation(.default, value: isSuccess)
      .overlay {
        let isVisible = phase == .empty && hasElapsed

        ProgressView()
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .overlay {
        let isVisible = phase == .failure

        Image(systemName: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .imageScale(.large)
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .aspectRatio(self.aspectRatio, contentMode: .fit)
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
