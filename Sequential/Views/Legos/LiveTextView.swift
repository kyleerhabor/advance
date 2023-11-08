//
//  LiveTextView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import OSLog
import SwiftUI
import VisionKit

struct LiveTextView<Scope>: NSViewRepresentable where Scope: URLScope {
  private let analyzer = ImageAnalyzer()

  let scope: Scope
  let orientation: CGImagePropertyOrientation
  @Binding var analysis: ImageAnalysis?
  private var supplementaryInterfaceHidden: Bool

  init(scope: Scope, orientation: CGImagePropertyOrientation, analysis: Binding<ImageAnalysis?>) {
    self.scope = scope
    self.orientation = orientation
    self._analysis = analysis
    self.supplementaryInterfaceHidden = false
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator
    // .imageSubject seems to be very unreliable, so I'm limiting it to text only.
    overlayView.preferredInteractionTypes = .automaticTextOnly
    overlayView.setSupplementaryInterfaceHidden(supplementaryInterfaceHidden, animated: false)

    analyze(overlayView, context: context)

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    overlayView.setSupplementaryInterfaceHidden(supplementaryInterfaceHidden, animated: true)

    // The user has to toggle the Live Text icon button to set the supplementary interface state. If a user is
    // highlighting items and toggles the state, it feels natural to also hide any highlighted items (else, you can't
    // hide them anymore).
    if supplementaryInterfaceHidden {
      overlayView.selectableItemsHighlighted = false
    }

    analyze(overlayView, context: context)
  }

  static func dismantleNSView(_ overlayView: ImageAnalysisOverlayView, coordinator: Coordinator) {
    coordinator.task?.cancel()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
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
        let frame = overlayView.frame
        let size = max(frame.width, frame.height) / context.environment.pixelLength

        try await scope.scoped {
          let url = try await analysisURL(size: size)
          let analysis = try await analyze(url: url)

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

  func analysisURL(size: Double) async throws -> URL {
    try Task.checkCancellation()

    // Is there a constant provided by Vision / VisionKit?
    let maxSize = 8192.0

    guard let source = CGImageSourceCreateWithURL(scope.url as CFURL, nil) else {
      return scope.url
    }

    let primary = CGImageSourceGetPrimaryImageIndex(source)

    // For those crazy enough to load an 8K+ image (i.e. me)
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, primary, nil) as? Dictionary<CFString, Any>,
          let imageSize = pixelSizeOfImageProperties(properties),
          imageSize.length() >= maxSize else {
      return scope.url
    }

    let size = min(size, maxSize - 1)

    Logger.livetext.info("Image at URL \"\(scope.url.string)\" has dimensions \(imageSize.width) / \(imageSize.height), exceeding Vision framework limit of \(maxSize.description); proceeding to downsample to size \(size.description)")

    return try downsample(source: source, index: primary, size: size)
  }

  func downsample(source: CGImageSource, index: Int, size: Double) throws -> URL {
    // We unfortunately can't just feed this to ImageAnalyzer since it results in a memory leak. Instead, we'll save
    // it to a file and feed the URL instead (which doesn't result in a memory leak!)
    let thumbnail = try source.resample(to: size.rounded(.up), index: index)

    guard let type = CGImageSourceGetType(source) else {
      throw ImageError.thumbnail
    }

    let url = URL.liveTextDownsampledDirectory.appending(component: UUID().uuidString)

    Logger.livetext.info("Copying downsampled image of URL \"\(self.scope.url.string)\" to destination \"\(url.string)\"")

    try FileManager.default.createDirectory(at: .liveTextDownsampledDirectory, withIntermediateDirectories: true)

    let count = 1

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, count, nil) else {
      throw ImageError.thumbnail
    }

    CGImageDestinationAddImage(destination, thumbnail, nil)

    guard CGImageDestinationFinalize(destination) else {
      throw ImageError.thumbnail
    }

    return url
  }

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

    var task: Task<Void, Never>?

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // v[iew] [menu]. I tried directly setting the .contextMenu on the LiveTextView, but it never seems to work.
      guard let vMenu = overlayView.superview?.superview?.superview?.menu else {
        return menu
      }

      let removing = [
        // Already implemented.
        menu.item(withTag: Tag.copyImage),
        // Too unstable (and slow).
        menu.item(withTag: Tag.shareImage),
        // TODO: Make this safer by only keeping known items.
        //
        // This could be done either by filtering this collection alone, or forgoing this whole process and requiring
        // the superview (i.e. the SwiftUI view) to reimplement it (which wouldn't be as native, but likely more robust).
        // I tried the latter prior, but couldn't get NSHostingView to overlay the view. I wonder if NSHostingController
        // will work better...
        menu.items.first { $0.title.hasPrefix("Search With") }
      ].compactMap { $0 }

      removing.forEach(menu.removeItem)

      let items = menu.items

      if !items.isEmpty {
        vMenu.addItem(.separator())
        items.forEach { item in
          menu.removeItem(item)
          vMenu.addItem(item)
        }
      }

      return vMenu
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
