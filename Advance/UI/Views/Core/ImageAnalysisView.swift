//
//  ImageAnalysisView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/24.
//

import DequeModule
import SwiftUI
import VisionKit

struct ImageAnalysisView: NSViewRepresentable {
  typealias BindMenuItemAction = () -> Void
  typealias BindMenuItem = (NSMenuItem, @escaping BindMenuItemAction) -> Void
  typealias TransformMenu = (NSMenu, BindMenuItem) -> NSMenu

  @Binding var selectedText: String
  @Binding var isHighlighted: Bool
  let analysis: ImageAnalysis?
  let interactionTypes: ImageAnalysisOverlayView.InteractionTypes
  let transformMenu: TransformMenu

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate
    overlayView.preferredInteractionTypes = interactionTypes

    setHighlightVisibility(
      overlayView,
      isVisible: false,
      isSupplementaryInterfaceHidden: context.environment.isImageAnalysisSupplementaryInterfaceHidden,
      animate: false
    )

    update(overlayView)

    return overlayView
  }
  
  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.delegate.representable = self

    if overlayView.preferredInteractionTypes != interactionTypes {
      overlayView.preferredInteractionTypes = interactionTypes
    } else {
      setHighlightVisibility(
        overlayView,
        isVisible: isHighlighted,
        isSupplementaryInterfaceHidden: context.environment.isImageAnalysisSupplementaryInterfaceHidden,
        animate: true
      )
    }
    
    update(overlayView)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(delegate: Delegate(representable: self))
  }

  private func update(_ overlayView: ImageAnalysisOverlayView) {
    overlayView.analysis = analysis
  }

  private func setHighlightVisibility(
    _ overlayView: ImageAnalysisOverlayView,
    isVisible: Bool,
    isSupplementaryInterfaceHidden: Bool,
    animate: Bool
  ) {
    let isHidden = !isVisible && isSupplementaryInterfaceHidden

    overlayView.setSupplementaryInterfaceHidden(isHidden, animated: animate)
    overlayView.selectableItemsHighlighted = isVisible
  }

  struct Coordinator {
    let delegate: Delegate

    init(delegate: Delegate) {
      self.delegate = delegate
    }
  }

  class Delegate: ImageAnalysisOverlayViewDelegate {
    var representable: ImageAnalysisView

    var actions: [NSMenuItem: BindMenuItemAction]

    init(representable: ImageAnalysisView) {
      self.representable = representable
      self.actions = [:]
    }

    func merge(_ overlayView: ImageAnalysisOverlayView, menu: NSMenu) -> NSMenu {
      guard let vmenu = sequence(first: overlayView, next: \.superview).firstNonNil(\.menu) else {
        return menu
      }

      let items = vmenu.items
      vmenu.removeAllItems()

      let iitem = menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.recommendedAppItems)

      guard iitem != NSMenu.itemIndexWithTagNotFoundStatus else {
        return menu
      }

      menu.items.insert(contentsOf: items, at: iitem)

      return menu
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
      // For some reason, this delegate method is called while SwiftUI reports to be updating views. This check
      // prevents the warning by verifying external updates to isHighlighted are protected against this method.
      guard representable.isHighlighted != highlightSelectedItems else {
        return
      }

      representable.isHighlighted = highlightSelectedItems
    }

    func textSelectionDidChange(_ overlayView: ImageAnalysisOverlayView) {
      // The representable seems to receieve the value after the menu has been presented. This means the view menu
      // can't depend on selectedText's value in the UI, but can in other areas, such as the action.
      //
      // Note that performing this update in overlayView(_:updatedMenuFor:for:at:) makes no difference.
      representable.selectedText = overlayView.selectedText
    }

    func overlayView(
      _ overlayView: ImageAnalysisOverlayView,
      updatedMenuFor menu: NSMenu,
      for event: NSEvent,
      at point: CGPoint
    ) -> NSMenu {
      actions = [:]

      let menu = representable.transformMenu(menu) { item, action in
        actions[item] = action

        item.target = self
        item.action = #selector(action(_:))
      }

      return merge(overlayView, menu: menu)
    }

    @objc func action(_ sender: NSMenuItem) {
      actions[sender]?()
    }
  }
}
