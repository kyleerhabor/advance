//
//  LiveTextView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import OSLog
import SwiftUI
import VisionKit
import UniformTypeIdentifiers

extension URL {
  static let temporaryLiveTextImagesDirectory = Self.temporaryImagesDirectory.appending(component: "Live Text")
}

extension ImageAnalysisOverlayView {
  func setHighlightVisibility(_ visible: Bool, supplementaryInterfaceHidden: Bool, animated: Bool) {
    let hidden = !visible && supplementaryInterfaceHidden

    self.setSupplementaryInterfaceHidden(hidden, animated: animated)
    self.selectableItemsHighlighted = visible
  }
}

extension ImageAnalysisOverlayView.MenuTag {
  static let searchWith = 0
}

extension ImageAnalyzer {
  static let maxSize = 8192

  static let errorDomain = "com.apple.VisionKit.ImageAnalyzer"
  static let errorCodeMaxSize = -10
}

extension ImageAnalyzer.AnalysisTypes {
  init(_ interactions: ImageAnalysisOverlayView.InteractionTypes) {
    self.init()

    if !interactions.isDisjoint(with: [.automatic, .automaticTextOnly, .textSelection, .dataDetectors]) {
      self.insert(.text)
    }

    if !interactions.isDisjoint(with: [.automatic, .visualLookUp]) {
      self.insert(.visualLookUp)
    }
  }
}

struct LiveTextView: NSViewRepresentable {
  let interactions: ImageAnalysisOverlayView.InteractionTypes
  let analysis: ImageAnalysis?
  @Binding var highlight: Bool

  private var supplementaryInterfaceHidden = false
  private var searchEngineHidden = false
  private var hidden: Bool {
    return !highlight && supplementaryInterfaceHidden
  }

  init(
    interactions: ImageAnalysisOverlayView.InteractionTypes,
    analysis: ImageAnalysis?,
    highlight: Binding<Bool>
  ) {
    self.interactions = interactions
    self.analysis = analysis
    self._highlight = highlight
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator

    // For some reason, using .automatic for subjects doesn't work 90% of the time.
    overlayView.preferredInteractionTypes = interactions

    // If we enable highlighting on initialization, it'll immediately go away but the supplementary interface will
    // be activated (i.e. have its accent color indicating the highlight state).
    overlayView.setHighlightVisibility(false, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: false)
    overlayView.analysis = analysis

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.setHighlight($highlight)
    context.coordinator.searchEngineHidden = searchEngineHidden

    if overlayView.preferredInteractionTypes != interactions {
      overlayView.preferredInteractionTypes = interactions
    }
    
    overlayView.setHighlightVisibility(highlight, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: true)

    overlayView.analysis = analysis
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(highlight: $highlight, searchEngineHidden: searchEngineHidden)
  }

  class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    @Binding var highlight: Bool
    var searchEngineHidden: Bool

    init(highlight: Binding<Bool>, searchEngineHidden: Bool) {
      self._highlight = highlight
      self.searchEngineHidden = searchEngineHidden
    }

    func setHighlight(_ highlight: Binding<Bool>) {
      self._highlight = highlight
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // v[iew] [menu]. I tried directly setting the .contextMenu on the LiveTextView, but it never seems to work.
      guard let vMenu = sequence(first: overlayView, next: \.superview).firstNonNil(\.menu) else {
        return menu
      }

      // TODO: Make this safer by only keeping known items.
      //
      // This could be done either by filtering this collection alone, or forgoing this whole process and requiring
      // the superview (i.e. the SwiftUI view) to reimplement it (which wouldn't be as native, but likely more robust).
      // I tried the latter prior, but couldn't get NSHostingView to overlay the view. I wonder if NSHostingController
      // will work better...
      var removing = [
        // Already implemented.
        menu.item(withTag: Tag.copyImage),
        // Too unstable (and slow). This does not need VisionKit to implement, anyway.
        menu.item(withTag: Tag.shareImage),
      ].compactMap { $0 }

      if searchEngineHidden,
         let item = menu.items.first(where: { $0.tag == Tag.searchWith && $0.isStandard }) {
        removing.append(item)
      }

      removing.forEach(menu.removeItem)

      let items = vMenu.items
      let index = menu.indexOfItem(withTag: Tag.recommendedAppItems)
      let end = index + items.count

      zip(index..<end, items).forEach { (index, item) in
        vMenu.removeItem(item)
        menu.insertItem(item, at: index)
      }

      return menu
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
      highlight = highlightSelectedItems
    }
  }
}

extension LiveTextView {
  func supplementaryInterfaceHidden(_ hidden: Bool) -> Self {
    var this = self
    this.supplementaryInterfaceHidden = hidden
    
    return this
  }

  func searchEngineHidden(_ hidden: Bool) -> Self {
    var this = self
    this.searchEngineHidden = hidden

    return this
  }
}
