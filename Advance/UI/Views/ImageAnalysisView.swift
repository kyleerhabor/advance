//
//  ImageAnalysisView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/25.
//

import Algorithms
import OSLog
import SwiftUI
import VisionKit

class ImageAnalysisViewDelegate: ImageAnalysisOverlayViewDelegate {
  var representable: ImageAnalysisView
  var actions: [NSMenuItem: () -> Void]

  init(representable: ImageAnalysisView) {
    self.representable = representable
    self.actions = [:]
  }

  func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
    self.representable.isSelectableItemsHighlighted = highlightSelectedItems
  }

  func overlayView(
    _ overlayView: ImageAnalysisOverlayView,
    updatedMenuFor menu: NSMenu,
    for event: NSEvent,
    at point: CGPoint,
  ) -> NSMenu {
    // For some reason, overlayView(_:didClose:) runs before action(_:), so we free actions here, instead.
    self.actions = [:]

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
    guard let action = self.actions[sender] else {
      Logger.ui.error("Could not find action for item '\(sender)'")

      return
    }
    
    action()
  }
}

struct ImageAnalysisViewCoordinator {
  let delegate: ImageAnalysisViewDelegate
}

struct ImageAnalysisView: NSViewRepresentable {
  @Binding var isSelectableItemsHighlighted: Bool
  let id: UUID
  let analysis: ImageAnalysis?
  let preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes
  let isSupplementaryInterfaceHidden: Bool
  let transformMenu: (ImageAnalysisViewDelegate, NSMenu, ImageAnalysisOverlayView) -> NSMenu

  private var isHidden: Bool {
    !self.isSelectableItemsHighlighted && self.isSupplementaryInterfaceHidden
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate
    overlayView.preferredInteractionTypes = self.preferredInteractionTypes
    overlayView.isSupplementaryInterfaceHidden = self.isHidden
    overlayView.analysis = self.analysis

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    let id = context.coordinator.delegate.representable.id
    context.coordinator.delegate.representable = self

    if overlayView.preferredInteractionTypes != self.preferredInteractionTypes {
      overlayView.preferredInteractionTypes = self.preferredInteractionTypes
    }

    let isSupplementaryInterfaceHidden = self.isHidden

    if overlayView.isSupplementaryInterfaceHidden != isSupplementaryInterfaceHidden {
      overlayView.setSupplementaryInterfaceHidden(isSupplementaryInterfaceHidden, animated: true)
    }

    if overlayView.selectableItemsHighlighted != self.isSelectableItemsHighlighted {
      overlayView.selectableItemsHighlighted = self.isSelectableItemsHighlighted
    }

    if id != self.id {
      // For some reason, setting this property may raise a layout constraint exception when the supplementary interface
      // is visible. Usually, AppKit will recover by breaking the violation.
      overlayView.analysis = self.analysis
    }
  }

  func makeCoordinator() -> ImageAnalysisViewCoordinator {
    ImageAnalysisViewCoordinator(delegate: ImageAnalysisViewDelegate(representable: self))
  }
}
