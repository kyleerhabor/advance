//
//  SettingsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

extension ColorScheme: RawRepresentable {
  public init?(rawValue: Int) {
    switch rawValue {
      case 0: self = .light
      case 1: self = .dark
      default: return nil
    }
  }
  
  public var rawValue: Int {
    switch self {
      case .light: 0
      case .dark: 1
      @unknown default: -1
    }
  }

  func app() -> NSAppearance? {
    switch self {
      case .light: .init(named: .aqua)
      case .dark: .init(named: .darkAqua)
      @unknown default: nil
    }
  }
}

struct SettingsView: View {
  typealias Scheme = ColorScheme?

  @AppStorage(StorageKeys.margin.rawValue) private var appMargin = 0
  @AppStorage(StorageKeys.appearance.rawValue) private var appearance: Scheme
  @State private var margin = 0.0

  var body: some View {
    Spacer()

    HStack {
      Spacer()

      Form {
        Picker("Appearance:", selection: $appearance) {
          Text("System")
            .tag(nil as Scheme)
          
          Divider()
          
          Text("Light").tag(.light as Scheme)
          Text("Dark").tag(.dark as Scheme)
        }
        
        Slider(value: $margin, in: 0...4, step: 1) {
          Text("Margins:")
        } minimumValueLabel: {
          Text("None")
        } maximumValueLabel: {
          Text("A lot")
        }
      }.frame(width: 384)

      Spacer()
    }
    .scenePadding()
    .onAppear {
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
