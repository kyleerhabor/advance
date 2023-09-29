//
//  DisplayImageView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import Combine
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct DisplayImageView<Content>: View where Content: View {
  typealias Subject = CurrentValueSubject<CGSize, Never>
  typealias PhaseContent = (Binding<AsyncImagePhase>) -> Content

  @Environment(\.pixelLength) private var pixel
  @State private var phase = AsyncImagePhase.empty
  @State private var size = CGSize()
  private var sizeSubject: Subject
  private var sizePublisher: AnyPublisher<CGSize, Never>

  let url: URL
  let transaction: Transaction
  let content: PhaseContent
  let failure: () async -> Void

  var body: some View {
    GeometryReader { proxy in
      content($phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.onReceive(sizePublisher) { size in
          self.size = size
        }.task(id: size) {
          // In very limited circumstances (though, I'm not sure what the cause is), full screening can cause this
          // modifier to be triggered for practically all images. This is also relevant for LiveTextView, so it seems
          // the whole view thinks it's active.
          guard !Task.isCancelled else {
            return
          }

          // Using `size` may result in the first image in the main canvas not being loaded.
          var size = proxy.size

          // FIXME: This is a hack to prevent immediate failing.
          //
          // For some reason, this closure is sometimes called when there is presumably no space to render it. It gets
          // a frame size of zero and may immediately update later to reflect a real value. The issue is, in some
          // instances, this can result in the user seeing the failure icon for a brief moment.
          guard size != .zero else {
            return
          }

          size = CGSize(
            width: size.width / pixel,
            height: size.height / pixel
          )

          do {
            // TODO: Support animated images
            //
            // Image I/O has CGAnimateImageAtURLWithBlock, which helps. I tried implementing this once, but it came out
            // poorly due to performance.
            do {
              let image = try await resample(to: size)

              // If an image is already present, don't perform an animation.
              //
              // Is it possible to just use .animation(_:value:)?
              if case .success = phase {
                phase = .success(image)
              } else {
                withTransaction(transaction) {
                  phase = .success(image)
                }
              }
            } catch ImageError.thumbnail {
              await failure()
            }
          } catch is CancellationError {
            // We don't want a CancellationError to e.g. change the visible image to a blank one, or for it to slightly
            // go blank then immediately come back.
          } catch {
            Logger.ui.error("Failed to resample image at \"\(url.string)\": \(error)")

            withTransaction(transaction) {
              phase = .failure(error)
            }
          }
        }
    }
  }

  init(url: URL, transaction: Transaction, @ViewBuilder content: @escaping PhaseContent, failure: @escaping () async -> Void) {
    self.url = url
    self.transaction = transaction
    self.content = content
    self.failure = failure

    let size = Subject(.init())

    self.sizeSubject = size
    self.sizePublisher = size
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  func resample(to size: CGSize) async throws -> Image {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    let thumbnail = try source.resample(to: size.length())
    
    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }
}
