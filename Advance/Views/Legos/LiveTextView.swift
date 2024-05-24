//
//  LiveTextView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/19/23.
//

import SwiftUI
import VisionKit

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
  static let search = 0
}

extension ImageAnalyzer {
  static let maxSize = 8192

  static let errorDomain = "com.apple.VisionKit.ImageAnalyzer"
  static let errorMaxSizeCode = -10
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

extension ImageAnalysis {
  var hasOutput: Bool {
    hasResults(for: [.text, .visualLookUp, .machineReadableCode])
  }
}

struct LiveTextView: NSViewRepresentable {
  @Binding private var isHighlighted: Bool
  
  private let interactions: ImageAnalysisOverlayView.InteractionTypes
  private let analysis: ImageAnalysis?

  private var supplementaryInterfaceHidden = false
  private var searchEngineHidden = false

  init(
    interactions: ImageAnalysisOverlayView.InteractionTypes,
    analysis: ImageAnalysis?,
    isHighlighted: Binding<Bool>
  ) {
    self.interactions = interactions
    self.analysis = analysis
    self._isHighlighted = isHighlighted
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator.delegate

    overlayView.preferredInteractionTypes = interactions

    // If we enable highlighting on initialization, it'll immediately go away but the supplementary interface will
    // be activated (i.e. have its accent color indicating the highlight state).
    overlayView.setHighlightVisibility(false, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: false)
    overlayView.analysis = analysis

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.delegate.searchEngineHidden = searchEngineHidden

    // This prevents an infinite loop in SwiftUI involving highlight.
    if overlayView.preferredInteractionTypes != interactions {
      overlayView.preferredInteractionTypes = interactions
    } else {
      overlayView.setHighlightVisibility(isHighlighted, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: true)
    }

    overlayView.analysis = analysis
  }

  func makeCoordinator() -> Coordinator {
    .init(delegate: .init(isHighlighted: $isHighlighted, searchEngineHidden: searchEngineHidden))
  }

  struct Coordinator {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    let delegate: Delegate

    init(delegate: Delegate) {
      self.delegate = delegate
    }
  }

  class Delegate: ImageAnalysisOverlayViewDelegate {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    @Binding private var isHighlighted: Bool
    var searchEngineHidden: Bool

    init(isHighlighted: Binding<Bool>, searchEngineHidden: Bool) {
      self._isHighlighted = isHighlighted
      self.searchEngineHidden = searchEngineHidden
    }

    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
      // v[iew] [menu]. I tried directly setting the .contextMenu on the LiveTextView, but it never seems to work.
      guard let vMenu = sequence(first: overlayView, next: \.superview).firstNonNil(\.menu) else {
        return menu
      }

      var removing = [
        // Already implemented.
        menu.item(withTag: Tag.copyImage),
        // Too unstable (and slow). This does not need VisionKit to implement, anyway.
        menu.item(withTag: Tag.shareImage),
      ].compactMap { $0 }

      if searchEngineHidden,
         let item = menu.items.first(where: { $0.tag == Tag.search && $0.isStandard }) {
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
      isHighlighted = highlightSelectedItems
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
