//
//  SequenceInfoButtonView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/6/23.
//

import SwiftUI

struct SequenceInfoButtonView: View {
  @Environment(\.seqInspecting) @Binding private var inspecting
  @Environment(\.seqInspection) @Binding private var inspection

  let ids: SequenceView.Selection

  var body: some View {
    Button("Get Info", systemImage: "info.circle") {
      inspection = ids
      inspecting = true
    }
  }
}
