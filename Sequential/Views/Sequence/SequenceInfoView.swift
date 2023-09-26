//
//  SequenceInfoView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/11/23.
//

import SwiftUI

struct HoveringViewModifier: ViewModifier {
  @Binding var hovering: Bool

  func body(content: Content) -> some View {
    content.onHover { hovering in
      self.hovering = hovering
    }
  }
}

extension View {
  func hovering(_ hovering: Binding<Bool>) -> some View {
    self.modifier(HoveringViewModifier(hovering: hovering))
  }

  func visible(_ visible: Bool) -> some View {
    self.opacity(visible ? 1 : 0)
  }
}

struct SequenceInfoView: View {
  @Environment(\.seqInspecting) @Binding private var inspecting
  @State private var hovering = false

  let images: [SeqImage]

  var body: some View {
    Form {
      let first = images.first!

      Section {
        Label(images.isMany ? "\(images.count) images" : first.url.lastPathComponent, systemImage: "tag")
      }

      Divider()

      Section {
        Label(images.compactMap(\.fileSize).reduce(0, +).formatted(.byteCount(style: .file)), systemImage: "doc")
      }
    }
    .fontDesign(.monospaced)
    .lineLimit(2)
    .overlay(alignment: .topTrailing) {
      Button("Close", systemImage: "xmark.circle.fill") {
//        Task {
          inspecting = false
//        }
      }
      .imageScale(.large)
      .foregroundStyle(.red.opacity(0.8))
      // This doesn't indicate to the user that the button is being pressed (like how .plain does), but it also doesn't
      // lag when the inspector goes away. We could try to implement it ourselves, but it would kind of suck.
      .buttonStyle(.plain)
      .labelStyle(.iconOnly)
      .alignmentGuide(VerticalAlignment.top) { $0.height / 12 }
      .visible(hovering)
    }
    .padding()
    .background(.regularMaterial.shadow(.drop(radius: 2)), in: .rect(cornerRadius: 8))
    .hovering($hovering)
  }
}
