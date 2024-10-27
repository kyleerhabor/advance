//
//  ImagesDetailPageView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import OSLog
import SwiftUI

struct ImagesDetailPageButtonView<Label>: View where Label: View {
  typealias Action = () -> Void

  private let edge: Edge.Set
  private let action: Action
  private let label: Label

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      label
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
        .padding()
        .padding(edge, 32)
        .frame(maxHeight: .infinity)
    }
    .visible(isHovering)
    .animation(.spring(duration: 0.35), value: isHovering)
    .buttonStyle(.borderless)
    .onHover { isHovering in
      self.isHovering = isHovering
    }
  }

  init(_ edge: Edge.Set, action: @escaping Action, @ViewBuilder label: () -> Label) {
    self.edge = edge
    self.action = action
    self.label = label()
  }
}

struct ImagesDetailPageView: View {
  @Environment(ImagesModel.self) private var images

  var body: some View {
    VStack {
      if let item = images.item {
        ImagesDetailItemView(item: item)
          .localized()
          .scaledToFit()
      }
    }
    // FIXME: ImagesDetailItemView scales based on aspect ratio, ignoring container height
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .leading) {
      ImagesDetailPageButtonView(.trailing) {
        guard let item = images.item,
              let i = images.items.index(id: item.id) else {
          return
        }

        let current = images.items[images.items.index(before: max(i, images.items.index(after: images.items.startIndex)))]
        images.itemID = current.id

        Task {
          do {
            try await images.submit(currentItem: current)
          } catch {
            Logger.model.error("\(error)")
          }
        }
      } label: {
        Label {
          Text("Images.Detail.Page.Previous")
        } icon: {
          Image(systemName: "chevron.backward.square.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
        }
      }
      // FIXME: This does nothing.
      .keyboardShortcut(.back)
    }
    .overlay(alignment: .trailing) {
      ImagesDetailPageButtonView(.leading) {
        guard let item = images.item,
              let i = images.items.index(id: item.id) else {
          return
        }

        // Yes, we need a distinct implementation from the back button. Collection.endIndex is "past the end", meaning
        // its indexing is not equivalent to the back button's reliance on Collection.startIndex. The only difference
        // is min is applied to the offset index, while max is applied on the input index.
        let current = images.items[min(images.items.index(after: i), images.items.lastIndex)]
        images.itemID = current.id

        Task {
          do {
            try await images.submit(currentItem: current)
          } catch {
            Logger.model.error("\(error)")
          }
        }
      } label: {
        Label {
          Text("Images.Detail.Page.Next")
        } icon: {
          Image(systemName: "chevron.forward.square.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
        }
      }
      // FIXME: This does nothing.
      .keyboardShortcut(.forward)
    }
    .focusedSceneValue(\.imagesDetailJump, ImagesNavigationJumpAction(identity: ImagesNavigationJumpIdentity(id: images.id, isReady: images.isReady)) { item in
      images.itemID = item.id

      Task {
        do {
          try await images.submit(currentItem: item)
        } catch {
          Logger.model.error("\(error)")
        }
      }
    })
  }
}
