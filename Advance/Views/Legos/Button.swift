//
//  Button.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/12/23.
//

import SwiftUI

struct MenuItemButton<I, Label>: View where I: Equatable, Label: View {
  typealias ActionItem = AppMenuActionItem<I>

  private let item: ActionItem
  private let label: Label

  var body: some View {
    Button {
      item()
    } label: {
      label
    }
    .disabled(!item.enabled)
  }

  init(item: ActionItem, @ViewBuilder label: () -> Label) {
    self.item = item
    self.label = label()
  }
}
