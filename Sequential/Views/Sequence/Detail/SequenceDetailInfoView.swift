//
//  SequenceDetailInfoView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/11/23.
//

import SwiftUI

struct SequenceDetailInfoView: View {
  @Environment(\.seqInspecting) @Binding private var inspecting
  @Environment(\.seqInspection) @Binding private var inspection
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value

  let images: [SeqImage]

  var body: some View {
    VStack {
      if inspecting {
        let images = images.filter(in: inspection, by: \.id)

        if !images.isEmpty {
          // TODO: Support dragging.
          SequenceInfoView(images: images)
            .padding()
            .padding(.trailing, Double(margins) * 3)
        }
      }
    }.animation(.default, value: inspecting)
  }
}
