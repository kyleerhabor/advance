//
//  ImageCollectionQuickLookView.swift
//  Advance
//
//  Created by Kyle Erhabor on 2/5/24.
//

import SwiftUI

struct ImageCollectionQuickLookView: View {
  @Binding var isOn: Bool

  var body: some View {
    Button(isOn ? "QuickLook.Hide" : "QuickLook.Show") {
      isOn.toggle()
    }
  }
}
