//
//  ImageAnalysisView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/25.
//

import Algorithms
import SwiftUI
import VisionKit

class ImageAnalysisViewDelegate: ImageAnalysisOverlayViewDelegate {
  var representable: ImageAnalysisView
  var actions: [NSMenuItem : () -> Void]

  init(representable: ImageAnalysisView) {
    self.representable = representable
    self.actions = [:]
  }

  func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
    self.representable.isSelectableItemsHighlighted = highlightSelectedItems
  }

  func overlayView(_ overlayView: ImageAnalysisOverlayView, didClose menu: NSMenu) {
    // Yes, this doesn't handle nested items.
    menu.items.forEach { self.actions[$0] = nil }
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

    return self.representable.transformMenu(self, menu, overlayView)
  }

  @objc func action(_ sender: NSMenuItem) {
    self.actions[sender]?()
  }
}

struct ImageAnalysisViewCoordinator {
  let delegate: ImageAnalysisViewDelegate
}

struct ImageAnalysisView: NSViewRepresentable {
  @Binding var isSelectableItemsHighlighted: Bool
  let analysis: ImageAnalysis?
  let preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes
  let isSupplementaryInterfaceHidden: Bool
  let transformMenu: (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    context.coordinator.delegate.representable = self

    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate
    overlayView.preferredInteractionTypes = self.preferredInteractionTypes
    self.setVisibility(overlayView, selectableItemsHighlighted: false, isAnimated: false)
    
    overlayView.analysis = self.analysis

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.delegate.representable = self

    if overlayView.preferredInteractionTypes == self.preferredInteractionTypes {
      self.setVisibility(
        overlayView,
        selectableItemsHighlighted: self.isSelectableItemsHighlighted,
        isAnimated: true,
      )
    } else {
      overlayView.preferredInteractionTypes = self.preferredInteractionTypes
    }

    overlayView.analysis = self.analysis
  }

  func makeCoordinator() -> ImageAnalysisViewCoordinator {
    ImageAnalysisViewCoordinator(delegate: ImageAnalysisViewDelegate(representable: self))
  }

  private func setVisibility(
    _ overlayView: ImageAnalysisOverlayView,
    selectableItemsHighlighted: Bool,
    isAnimated animate: Bool,
  ) {
    overlayView.setSupplementaryInterfaceHidden(
      !selectableItemsHighlighted && self.isSupplementaryInterfaceHidden,
      animated: animate,
    )

    overlayView.selectableItemsHighlighted = selectableItemsHighlighted
  }
}
