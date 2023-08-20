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

  @Environment(\.pixelLength) private var pixel
  @State private var size = CGSize()
  private var sizeSubject: Subject
  private var sizePublisher: AnyPublisher<CGSize, Never>

  let url: URL
  @Binding var phase: AsyncImagePhase
  let transaction: Transaction
  let content: Content

  var body: some View {
    GeometryReader { proxy in
      content
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
            withTransaction(transaction) {
              phase = .failure(error)
            }
          }
        }
    }
  }

  init(url: URL, phase: Binding<AsyncImagePhase>, transaction: Transaction, @ViewBuilder content: () -> Content) {
    self.url = url
    self._phase = phase
    self.transaction = transaction
    self.content = content()

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
