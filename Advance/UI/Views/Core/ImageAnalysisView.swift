//
//  ImageAnalysisView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/24.
//

import SwiftUI
import VisionKit

struct ImageAnalysisView: NSViewRepresentable {
  @Binding var isHighlighted: Bool
  let analysis: ImageAnalysis?
  let interactionTypes: ImageAnalysisOverlayView.InteractionTypes

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

    init(representable: ImageAnalysisView) {
      self.representable = representable
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
      // For some reason, this delegate method is called while SwiftUI reports to be updating views. This check
      // prevents the warning by verifying external updates to isHighlighted are protected against this method.
      guard representable.isHighlighted != highlightSelectedItems else {
        return
      }

      representable.isHighlighted = highlightSelectedItems
    }
  }
}
