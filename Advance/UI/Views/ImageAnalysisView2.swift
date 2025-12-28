//
//  ImageAnalysisView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/25.
//

import Algorithms
import SwiftUI
import VisionKit

class ImageAnalysisViewDelegate: ImageAnalysisOverlayViewDelegate {
  var representable: ImageAnalysisView2
  var actions: [NSMenuItem : () -> Void]

  init(representable: ImageAnalysisView2) {
    self.representable = representable
    self.actions = [:]
  }

  func overlayView(
    _ overlayView: ImageAnalysisOverlayView,
    updatedMenuFor menu: NSMenu,
    for event: NSEvent,
    at point: CGPoint,
  ) -> NSMenu {
    guard let vmenu = sequence(first: overlayView, next: \.superview).firstNonNil(\.menu) else {
      return menu
    }

    let vitems = vmenu.items
    vmenu.removeAllItems()
    menu.items.insert(
      contentsOf: vitems,
      at: menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.recommendedAppItems),
    )

    return self.representable.transform(self, menu, overlayView)
  }

  @objc func action(_ sender: NSMenuItem) {
    actions[sender]?()
  }
}

struct ImageAnalysisViewCoordinator {
  let delegate: ImageAnalysisViewDelegate
}

struct ImageAnalysisView2: NSViewRepresentable {
  let analysis: ImageAnalysis?
  let preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes
  let transform: (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu
//  let isSupplementaryInterfaceHidden: Bool

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    context.coordinator.delegate.representable = self

    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate
    overlayView.analysis = analysis
    overlayView.preferredInteractionTypes = preferredInteractionTypes
//    overlayView.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.delegate.representable = self
    overlayView.delegate = context.coordinator.delegate
    overlayView.analysis = analysis
    overlayView.preferredInteractionTypes = preferredInteractionTypes
//    overlayView.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden
  }

  func makeCoordinator() -> ImageAnalysisViewCoordinator {
    ImageAnalysisViewCoordinator(delegate: ImageAnalysisViewDelegate(representable: self))
  }
}
