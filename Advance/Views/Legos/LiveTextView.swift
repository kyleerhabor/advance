//
//  LiveTextView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/19/23.
//

import OSLog
import SwiftUI
import VisionKit

extension URL {
  static let temporaryLiveTextImagesDirectory = Self.temporaryImagesDirectory.appending(component: "Live Text")
}

extension Duration {
  // We want to use a reasonable number where a subject analysis should complete well before the deadline but enough
  // distance where delays won't impact it (e.g. flooding Vision with requests). In addition, our delay can't be too
  // long, else open resources may be held for too long (e.g. security scoped resources).
  static let subjectAnalysisTimeout = Self.seconds(30)
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

struct ImageAnalysisResult {
  let id: UUID
  let analysis: ImageAnalysis
}

struct LiveTextView: NSViewRepresentable {
  typealias SubjectAnalysisHandler = (() async -> Void) async -> Void

  private let interactions: ImageAnalysisOverlayView.InteractionTypes
  private let result: ImageAnalysisResult?
  private let subjectAnalysisHandler: SubjectAnalysisHandler
  @Binding private var highlight: Bool

  private var supplementaryInterfaceHidden = false
  private var searchEngineHidden = false

  init(
    interactions: ImageAnalysisOverlayView.InteractionTypes,
    result: ImageAnalysisResult?,
    highlight: Binding<Bool>,
    subjectAnalysisHandler: @escaping SubjectAnalysisHandler
  ) {
    self.interactions = interactions
    self.result = result
    self._highlight = highlight
    self.subjectAnalysisHandler = subjectAnalysisHandler
  }

  func makeNSView(context: Context) -> ImageAnalysisOverlayView {
    let overlayView = ImageAnalysisOverlayView()
    overlayView.delegate = context.coordinator

    overlayView.preferredInteractionTypes = interactions

    // If we enable highlighting on initialization, it'll immediately go away but the supplementary interface will
    // be activated (i.e. have its accent color indicating the highlight state).
    overlayView.setHighlightVisibility(false, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: false)
    overlayView.analysis = result?.analysis

    return overlayView
  }

  func updateNSView(_ overlayView: ImageAnalysisOverlayView, context: Context) {
    context.coordinator.setHighlight($highlight)
    context.coordinator.searchEngineHidden = searchEngineHidden

    if context.coordinator.analysisID != result?.id {
      context.coordinator.analysisID = result?.id
      context.coordinator.subjectAnalysisComplete = false
    }

    // This prevents an infinite loop in SwiftUI involving highlight.
    if overlayView.preferredInteractionTypes != interactions {
      overlayView.preferredInteractionTypes = interactions
    } else {
      overlayView.setHighlightVisibility(highlight, supplementaryInterfaceHidden: supplementaryInterfaceHidden, animated: false)
    }

    overlayView.analysis = result?.analysis

    guard overlayView.activeInteractionTypes.contains(.imageSubject) && !context.coordinator.subjectAnalysisComplete else {
      return
    }

    context.coordinator.subjectAnalysisTask?.cancel()
    context.coordinator.subjectAnalysisTask = .init(priority: .low) { [weak overlayView, weak coordinator = context.coordinator] in
      guard !Task.isCancelled else {
        return
      }

      await subjectAnalysisHandler {
        await race {
          guard let overlayView, let coordinator else {
            return
          }

          // This is a hacky method for performing subject analysis. beginSubjectAnalysisIfNecessary() is a request that
          // returns immediately, which is unsuitable for us since the analysis needs to be scoped.
          //
          // subjects will sometimes never return, which is okay in a way (the task will just be infinitely suspended).
          // It's a problem where the scope may be left indefinitely open, leaking resources. This choose method will
          // just throw if it elapses, returning from the handler. It does mean that subjects will drop its scope, but
          // that shouldn't be a problem, since it's more than likely just indefinitely suspended.
          //
          // Unfortunately, using this with rare (which ignores the execution of this closure when rhs returns first)
          // seems to result in a memory leak. If I had to presume, since subjects sometimes never returns, the task
          // group is retained indefinitely. Fortunately, the resource leak seems to be minimal; but we could do better.
          _ = await overlayView.subjects

          guard coordinator.analysisID == result?.id else {
            return
          }

          context.coordinator.subjectAnalysisComplete = true
        } rhs: {
          do {
            try await Task.sleep(for: .subjectAnalysisTimeout)
          } catch {
            return
          }

          Logger.ui.debug("Took too long to analyze Live Text subjects; exiting handler...")
        }
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      highlight: $highlight,
      analysisID: result?.id,
      searchEngineHidden: searchEngineHidden
    )
  }

  static func dismantleNSView(_ overlayView: ImageAnalysisOverlayView, coordinator: Coordinator) {
    coordinator.subjectAnalysisTask?.cancel()
  }

  class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
    typealias Tag = ImageAnalysisOverlayView.MenuTag

    @Binding private var highlight: Bool
    var searchEngineHidden: Bool

    var analysisID: UUID?
    var subjectAnalysisComplete = false
    var subjectAnalysisTask: Task<Void, Never>?

    init(highlight: Binding<Bool>, analysisID: UUID?, searchEngineHidden: Bool) {
      self._highlight = highlight
      self.analysisID = analysisID
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
