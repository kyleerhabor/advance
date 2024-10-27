//
//  SettingsExtraView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/23.
//

import Defaults
import SwiftUI

struct SettingsExtraView: View {
  @Default(.liveTextDownsample) private var liveTextDownsample

  var body: some View {
    LabeledContent("Settings.Section.LiveText") {
      Toggle(isOn: $liveTextDownsample) {
        Text("Settings.LiveText.Downsample.Label")
        
        Text("Settings.LiveText.Downsample.Note")
      }
    }
  }
}
