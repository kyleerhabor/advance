//
//  SettingsLiveTextSupportViewModifier.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/4/24.
//

import SwiftUI
import VisionKit

struct SettingsLiveTextSupportViewModifier: ViewModifier {
  private let isSupported = ImageAnalyzer.isSupported

  func body(content: Content) -> some View {
    content
      .disabled(!isSupported)
      .help(isSupported ? Text(verbatim: "") : Text("Settings.LiveText.Unsupported"))
  }
}

extension View {
  func liveTextSupport() -> some View {
    self.modifier(SettingsLiveTextSupportViewModifier())
  }
}
