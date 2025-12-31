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
    highlightSelectedItemsDidChange highlightSelectedItems: Bool,
  ) {
    representable.selectableItemsHighlighted = highlightSelectedItems
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

    return self.representable.transformMenu.action(self, menu, overlayView)
  }

  @objc func action(_ sender: NSMenuItem) {
    actions[sender]?()
  }
}

struct ImageAnalysisViewCoordinator {
  let delegate: ImageAnalysisViewDelegate
}

class ImageAnalysisViewTransformMenuAction {
  let action: (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu

  init(action: @escaping (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu) {
    self.action = action
  }
}

struct ImageAnalysisView2: NSViewRepresentable {
  @Binding var selectableItemsHighlighted: Bool
  let analysis: ImageAnalysis?
  let preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes
  let isSupplementaryInterfaceHidden: Bool
  let transformMenu: ImageAnalysisViewTransformMenuAction

  init(
    selectableItemsHighlighted: Binding<Bool>,
    analysis: ImageAnalysis?,
    preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes,
    isSupplementaryInterfaceHidden: Bool,
    transformMenu: @escaping (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu,
  ) {
    self.analysis = analysis
    self.preferredInteractionTypes = preferredInteractionTypes
    self.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden
    self._selectableItemsHighlighted = selectableItemsHighlighted
    self.transformMenu = ImageAnalysisViewTransformMenuAction(action: transformMenu)
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    context.coordinator.delegate.representable = self

    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate
    overlayView.analysis = analysis
    overlayView.preferredInteractionTypes = preferredInteractionTypes
    overlayView.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden
    overlayView.selectableItemsHighlighted = selectableItemsHighlighted

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.delegate.representable = self
    overlayView.delegate = context.coordinator.delegate
    overlayView.analysis = analysis
    overlayView.preferredInteractionTypes = preferredInteractionTypes
    overlayView.isSupplementaryInterfaceHidden = isSupplementaryInterfaceHidden
    overlayView.selectableItemsHighlighted = selectableItemsHighlighted
  }

  func makeCoordinator() -> ImageAnalysisViewCoordinator {
    ImageAnalysisViewCoordinator(delegate: ImageAnalysisViewDelegate(representable: self))
  }
}
