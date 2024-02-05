//
//  ImageCollectionBookmarkView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/20/23.
//

import SwiftUI

struct ImageCollectionBookmarkView: View {
  @Binding var isOn: Bool

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      if isOn {
        label.labelStyle(.titleAndIcon)
      } else {
        label
      }
    }.symbolVariant(isOn ? .fill : .none)
  }

  var label: some View {
    Label("Bookmark", systemImage: "bookmark")
  }
}
