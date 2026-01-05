//
//  ImageCollectionSidebarEmptyView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/15/23.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImageCollectionEmptySidebarLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 8) {
      configuration.icon
        .symbolRenderingMode(.hierarchical)

      configuration.title
        .font(.subheadline)
        .fontWeight(.medium)
    }
  }
}

struct ImageCollectionSidebarEmptyView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.imagesID) private var id
  @State private var isFileImporterPresented = false

  let visible: Bool

  var body: some View {
    Button {
      isFileImporterPresented = true
    } label: {
      Label {
        Text("Images.Sidebar.Import")
      } icon: {
        Image(systemName: "square.and.arrow.down")
          .resizable()
          .scaledToFit()
          .frame(width: 24)
      }
      .labelStyle(ImageCollectionEmptySidebarLabelStyle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .disabled(!visible)
  }
}
