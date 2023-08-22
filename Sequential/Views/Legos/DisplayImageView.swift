//
//  DisplayImageView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import Combine
import OSLog
import SwiftUI

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

  var body: some View {
    GeometryReader { proxy in
      content($phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.onReceive(sizePublisher) { size in
          self.size = size
        }.task(id: size) {
          // FIXME: This is a hack to prevent immediate failing.
          //
          // For some reason, the initial call gets a frame size of zero, and then immediately updates with the proper
          // value. This isn't caused by the default state value of `size` being zero, however. This task is, straight
          // up, just called when there is presumably no frame to present the view.
          guard size != .zero else {
            return
          }

          let size = CGSize(
            width: size.width / pixel,
            height: size.height / pixel
          )

          do {
            let image = try await resample(to: size)

            // If an image is already present, don't perform an animation. Is it possible to just use
            // .animation(_:value:) instead?
            if case .success = phase {
              phase = .success(image)
            } else {
              withTransaction(transaction) {
                phase = .success(image)
              }
            }
          } catch {
            // We don't want a CancellationError to e.g. change the visible image to a blank one, or for it to slightly
            // go blank then immediately come back.
            guard !(error is CancellationError) else {
              return
            }

            Logger.ui.error("Failed to resample image at \"\(url.string)\": \(error)")

            withTransaction(transaction) {
              phase = .failure(error)
            }
          }
        }
    }
  }

  init(url: URL, transaction: Transaction, @ViewBuilder content: @escaping PhaseContent) {
    self.url = url
    self.transaction = transaction
    self.content = content

    let size = Subject(.init())

    self.sizeSubject = size
    self.sizePublisher = size
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  nonisolated func resample(to size: CGSize) async throws -> Image {
    let options: [CFString : Any] = [
      // We're not going to use kCGImageSourceShouldAllowFloat since the sizes can get very precise.
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: size.length(),
      kCGImageSourceCreateThumbnailWithTransform: true
    ]

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    let index = CGImageSourceGetPrimaryImageIndex(source)

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
      throw ImageError.undecodable
    }

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return Image(nsImage: .init(cgImage: thumbnail, size: size))
  }
}
