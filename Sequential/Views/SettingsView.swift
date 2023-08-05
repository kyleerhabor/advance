//
//  SettingsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

struct SettingsView: View {
  @AppStorage(StorageKeys.fullWindow.rawValue) private var fullWindow: Bool = false
  @AppStorage(StorageKeys.margin.rawValue) private var appMargin = 0
  @State private var margin = 0.0

  var body: some View {
    Spacer()

    HStack {
      Spacer()
      
      Form {
        Toggle(isOn: $fullWindow) {
          Text("Cover the full window")
        }

        Slider(value: $margin, in: 0...4, step: 1) {
          Text("Margins:")
        } minimumValueLabel: {
          Text("None")
        } maximumValueLabel: {
          Text("A lot")
        }
      }.scenePadding()

      Spacer()
    }.onAppear {
      margin = Double(appMargin)
    }.onChange(of: margin) {
      appMargin = Int(margin)
    }

    Spacer()
  }
}

#Preview {
  SettingsView()
}
