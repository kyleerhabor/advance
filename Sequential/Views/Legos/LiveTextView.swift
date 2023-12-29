//
//  LiveTextView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import OSLog
import SwiftUI
import VisionKit

extension URL {
  static let temporaryLiveTextImagesDirectory = Self.temporaryImagesDirectory.appending(component: "Live Text")
}

extension ImageAnalysisOverlayView {
  func setHighlightVisibility(highlight: Bool, supplementaryInterfaceHidden: Bool, animated: Bool) {
    let hidden = !highlight && supplementaryInterfaceHidden

    self.setSupplementaryInterfaceHidden(hidden, animated: animated)
    self.selectableItemsHighlighted = highlight
  }
}

struct LiveTextView<Scope>: NSViewRepresentable where Scope: URLScope {
  private let analyzer = ImageAnalyzer()

  let scope: Scope
  let orientation: CGImagePropertyOrientation
  @Binding var highlight: Bool
  @Binding var analysis: ImageAnalysis?
  private var supplementaryInterfaceHidden: Bool
  private var hidden: Bool {
    return !highlight && supplementaryInterfaceHidden
  }

  init(scope: Scope, orientation: CGImagePropertyOrientation, highlight: Binding<Bool>, analysis: Binding<ImageAnalysis?>) {
    self.scope = scope
    self.orientation = orientation
    self._highlight = highlight
    self._analysis = analysis
    self.supplementaryInterfaceHidden = false
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator
    // .automatic would be nice, but it takes too long to activate. Maybe lock it behind a setting?
    overlayView.preferredInteractionTypes = .automaticTextOnly

    // If we enable highlighting on initialization, it'll immediately go away but the supplementary interface will
    // be activated (i.e. have its accent color indicating the highlight state).
    overlayView.setHighlightVisibility(highlight: false, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: false)

    analyze(overlayView, context: context)

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.setHighlight($highlight)

    overlayView.setHighlightVisibility(highlight: highlight, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: true)

    analyze(overlayView, context: context)
  }

  static func dismantleNSView(_ overlayView: ImageAnalysisOverlayView, coordinator: Coordinator) {
    coordinator.task?.cancel()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(highlight: $highlight)
  }

  @MainActor
  func analyze(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    guard analysis == nil else {
      overlayView.analysis = analysis

      return
    }

    guard context.coordinator.task == nil else {
      return
    }

    context.coordinator.task = .init {
      do {
//        let frame = overlayView.frame
//        let size = max(frame.width, frame.height) / context.environment.pixelLength

        try await scope.scoped {
//          let url = try await analysisURL(size: size)
          let analysis = try await analyze(url: scope.url)

          self.analysis = analysis
          overlayView.analysis = analysis
        }
      } catch is CancellationError {
        Logger.ui.info("Tried to analyze image, but Task was cancelled.")
      } catch {
        Logger.ui.error("Could not analyze image: \(error)")
      }

      context.coordinator.task = nil
    }
  }

//  func analysisURL(size: Double) async throws -> URL {
//    try Task.checkCancellation()
//
//    // Is there a constant provided by Vision / VisionKit?
//    let maxSize = 8192
//
//    guard let source = CGImageSourceCreateWithURL(scope.url as CFURL, nil) else {
//      return scope.url
//    }
//
//    let primary = CGImageSourceGetPrimaryImageIndex(source)
//
//    // For those crazy enough to load an 8K+ image (i.e. me)
//    //
//    // FIXME: We should only downsample when the error indicates the image was too large.
//    guard let properties = source.properties() as? MapCF,
//          let imageSize = ImageSize(from: properties) else {
//      return scope.url
//    }
//
//    let length = imageSize.length
//
//    guard length >= maxSize else {
//      return scope.url
//    }
//
//    let size = min(length, maxSize - 1)
//
//    Logger.ui.info("Image at URL \"\(scope.url.string)\" has dimensions \(imageSize.width) / \(imageSize.height), exceeding Vision framework limit of \(maxSize.description); proceeding to downsample to size \(size.description)")
//
//    return try downsample(source: source, index: primary, size: size)
//  }
//
//  func downsample(source: CGImageSource, index: Int, size: Int) throws -> URL {
//    // We unfortunately can't just feed this to ImageAnalyzer since it results in a memory leak. Instead, we'll save
//    // it to a file and feed the URL instead (which doesn't result in a memory leak!)
//    guard let thumbnail = source.resample(to: size, index: index) else {
//      throw ImageError.thumbnail
//    }
//
//    guard let type = CGImageSourceGetType(source) else {
//      throw ImageError.thumbnail
//    }
//
//    let directory = URL.temporaryLiveTextImagesDirectory
//    let url = directory.appending(component: UUID().uuidString)
//
//    Logger.ui.info("Copying downsampled image of URL \"\(self.scope.url.string)\" to destination \"\(url.string)\"")
//
//    let count = 1
//
//    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, count, nil) else {
//      throw ImageError.thumbnail
//    }
//
//    CGImageDestinationAddImage(destination, thumbnail, nil)
//
//    try FileManager.default.creatingDirectories(at: directory, code: .fileNoSuchFile) {
//      guard CGImageDestinationFinalize(destination) else {
//        throw ImageError.thumbnail
//      }
//    }
//
//    return url
//  }

  func analyze(url: URL) async throws -> ImageAnalysis {
    // FIXME: VisionKit sometimes complains about analyzing over 10 images.
    //
    // VisionKit's analyze method doesn't seem to check for cancellation itself. If we wanted to fix this, we'd need a
    // handle from users, but it would be difficult to schedule, given we'd need to know when a slot becomes available
    // and which view on-screen is most relevant to be given the priority (assuming we don't want to leave the user in
    // a weird state).
    let exec = try await time {
      try await analyzer.analyze(imageAt: url, orientation: orientation, configuration: .init(.text))
    }

    Logger.ui.info("Took \(exec.duration) to analyze image at URL \"\(url.string)\"")

    return exec.value
  }

  class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    @Binding var highlight: Bool
    var task: Task<Void, Never>?

    init(highlight: Binding<Bool>, task: Task<Void, Never>? = nil) {
      self._highlight = highlight
      self.task = task
    }

    func setHighlight(_ highlight: Binding<Bool>) {
      self._highlight = highlight
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // v[iew] [menu]. I tried directly setting the .contextMenu on the LiveTextView, but it never seems to work.
      guard let vMenu = sequence(first: overlayView, next: \.superview).firstNonNil(\.menu) else {
        return menu
      }

      // TODO: Make this safer by only keeping known items.
      //
      // This could be done either by filtering this collection alone, or forgoing this whole process and requiring
      // the superview (i.e. the SwiftUI view) to reimplement it (which wouldn't be as native, but likely more robust).
      // I tried the latter prior, but couldn't get NSHostingView to overlay the view. I wonder if NSHostingController
      // will work better...
      let removing = [
        // Already implemented.
        menu.item(withTag: Tag.copyImage),
        // Too unstable (and slow). This does not need VisionKit / Live Text to implement, anyway.
        menu.item(withTag: Tag.shareImage),
        // Always opens in Safari, which is undesirable.
        menu.items.first { $0.title.hasPrefix("Search With") }
      ].compactMap { $0 }

      removing.forEach(menu.removeItem)

      let items = vMenu.items
      let index = menu.indexOfItem(withTag: Tag.recommendedAppItems)
      let end = index + items.count

      zip(index..<end, items).forEach { (index, item) in
        vMenu.removeItem(item)
        menu.insertItem(item, at: index)
      }

      return menu
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
      highlight = highlightSelectedItems
    }
  }
}

extension LiveTextView {
  func supplementaryInterfaceHidden(_ hidden: Bool) -> Self {
    var this = self
    this.supplementaryInterfaceHidden = hidden
    
    return this
  }
}
