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
  let icons: Bool

  func makeNSView(context: Context) -> NSViewType {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator
    // .imageSubject seems to be very unreliable, so I'm limiting it to text only.
    overlayView.preferredInteractionTypes = .automaticTextOnly

    return overlayView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.setSupplementaryInterfaceHidden(!icons, animated: true)

    let analyzer = ImageAnalyzer()

    // FIXME: VisionKit is still complaining about analyzing over 10 images sometimes.
    context.coordinator.task = .init {
      do {
        let analysis = try await analyzer.analyze(imageAt: url, orientation: .up, configuration: .init(.text))

        nsView.analysis = analysis
      } catch {
        Logger.ui.error("Could not analyze contents of \"\(url.string)\": \(error)")
      }
    }
  }

  static func dismantleNSView(_ nsView: ImageAnalysisOverlayView, coordinator: Coordinator) {
    coordinator.task = nil
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
    var task: Task<Void, Never>? = nil

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // There better be a simpler way to do this.
      guard let vMenu = overlayView.superview?.superview?.superview?.menu else {
        return menu
      }

      let items = menu.items

      if !items.isEmpty {
        items.forEach { item in
          menu.removeItem(item)
          vMenu.addItem(item)
        }
      }

      return vMenu
    }
  }
}
