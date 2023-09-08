//
//  SequenceInfoButtonView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/6/23.
//

import SwiftUI

struct SequenceInfoButtonView: View {
  @Environment(\.seqInspecting) private var inspecting
  @Environment(\.seqInspection) private var inspection

  let ids: SequenceView.Selection

  var body: some View {
    Button("Get Info", systemImage: "info.circle") {
      inspection.wrappedValue = ids
      inspecting.wrappedValue = true
    }
  }
}
