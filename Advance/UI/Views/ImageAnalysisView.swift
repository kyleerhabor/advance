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

  // For some reason, implementing any of the following methods (not the implementations, themselves) results in excess
  // memory being retained for a short duration of time (e.g., 10 seconds) when the user is not interacting with the app.

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

  init(
    isSelectableItemsHighlighted: Binding<Bool>,
    analysis: ImageAnalysis?,
    preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes,
    isSupplementaryInterfaceHidden: Bool,
    transformMenu: @escaping (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu,
  ) {
    self.analysis = analysis
    self._isSelectableItemsHighlighted = isSelectableItemsHighlighted
    self.preferredInteractionTypes = preferredInteractionTypes
    self.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden
    self.transformMenu = transformMenu
  }

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
