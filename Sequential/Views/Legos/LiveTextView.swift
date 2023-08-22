//
//  LiveTextView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import OSLog
import SwiftUI
import VisionKit

struct LiveTextView: NSViewRepresentable {
  typealias NSViewType = ImageAnalysisOverlayView

  let url: URL
  private var supplementaryInterfaceHidden: Bool

  init(url: URL) {
    self.url = url
    self.supplementaryInterfaceHidden = false
  }

  func makeNSView(context: Context) -> NSViewType {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator
    // .imageSubject seems to be very unreliable, so I'm limiting it to text only.
    overlayView.preferredInteractionTypes = .automaticTextOnly

    return overlayView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.setSupplementaryInterfaceHidden(supplementaryInterfaceHidden, animated: true)

    let analyzer = ImageAnalyzer()

    // FIXME: VisionKit is still complaining about analyzing over 10 images at times.
    //
    // The analyze method doesn't seem to check for cancellation itself.
    context.coordinator.task = .init {
      // The task may immediately be cancelled when e.g. scrolling very quickly through a SequenceView.
      guard !Task.isCancelled else {
        return
      }

      do {
        let exec = try await time {
          try await analyzer.analyze(imageAt: url, orientation: .up, configuration: .init(.text))
        }

        Logger.ui.info("Took \(exec.duration) to analyze image at \"\(url.string)\"")

        nsView.analysis = exec.value
      } catch {
        Logger.ui.error("Could not analyze image at \"\(url.string)\": \(error)")
      }
    }
  }

  static func dismantleNSView(_ nsView: ImageAnalysisOverlayView, coordinator: Coordinator) {
    coordinator.task?.cancel()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    var task: Task<Void, Never>?

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // There better be a simpler way to do this.
      guard let vMenu = overlayView.superview?.superview?.superview?.menu else {
        return menu
      }

      let removal = [
        // Already implemented.
        menu.item(withTag: Tag.copyImage),
        // Too unstable (and slow).
        menu.item(withTag: Tag.shareImage),
        // This always opens in Safari, which is annoying.
        //
        // I wonder if other search engines are considered. How about other languages?
        menu.item(withTitle: "Search With Google")
      ].compactMap { $0 }

      removal.forEach(menu.removeItem)

      let items = menu.items

      if !items.isEmpty {
        // ... and this as well.
        vMenu.addItem(.separator())
        items.forEach { item in
          menu.removeItem(item)
          vMenu.addItem(item)
        }
      }

      return vMenu
    }
  }

  func supplementaryInterfaceHidden(_ hidden: Bool) -> Self {
    var this = self
    this.supplementaryInterfaceHidden = hidden

    return this
  }
}
