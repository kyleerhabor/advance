//
//  SettingsExtraView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/23.
//

import Defaults
import SwiftUI
import VisionKit

struct SettingsExtraView: View {
  @Default(.liveText) private var liveText
  @Default(.liveTextSearchWith) private var liveTextSearchWith
  @Default(.liveTextDownsample) private var liveTextDownsample
  private let liveTextSupported = ImageAnalyzer.isSupported

  var body: some View {
    LabeledContent("Live Text:") {
      Group {
        Toggle(isOn: $liveTextSearchWith) {
          Text("Show menu item for search engine")

          Text("This will always open in Safari.")
        }

        Toggle(isOn: $liveTextDownsample) {
          Text("Downsample very large images")

          Text("If an image is too large to be analyzed, a lower-resolution representation of the image will be used instead. This involves writing the image to disk, which will be cleared the next time the app is launched.")
        }
      }
      .disabled(!liveTextSupported || !liveText)
      .help(liveTextSupported ? "" : "This device does not support Live Text.")
    }
  }
}
