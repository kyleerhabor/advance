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

  var body: some View {
    LabeledContent("Settings.Section.LiveText") {
      GroupBox {
        Toggle(isOn: $liveTextSearchWith) {
          Text("Settings.LiveText.Search.Label")

          Text("Settings.LiveText.Search.Note")
        }

        Toggle(isOn: $liveTextDownsample) {
          Text("Settings.LiveText.Downsample.Label")

          Text("Settings.LiveText.Downsample.Note")
        }
      }
      .disabled(!liveText)
      .liveTextSupport()
    }
  }
}
