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
    }.disabled(!item.enabled)
  }

  init(item: ActionItem, @ViewBuilder label: () -> Label) {
    self.item = item
    self.label = label()
  }
}

struct MenuItemToggle<I, Content>: View where I: Equatable, Content: View {
  typealias Item = AppMenuToggleItem<I>

  let toggle: Item
  @ViewBuilder var content: (Binding<Bool>) -> Content

  private var isOn: Binding<Bool> {
    .init {
      toggle.state
    } set: { isOn in
      toggle(state: isOn)
    }
  }

  var body: some View {
    content(isOn)
      .disabled(!toggle.item.enabled)
  }
}
