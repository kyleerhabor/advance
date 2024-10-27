//
//  LiveTextView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/19/23.
//

import VisionKit

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
