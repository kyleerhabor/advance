//
//  UI+View.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/9/24.
//

import Combine
import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
  typealias Value = Anchor<CGRect>?

  static var defaultValue: Value = nil

  static func reduce(value: inout Value, nextValue: () -> Value) {
    guard let next = nextValue() else {
      return
    }

    value = next
  }
}

struct VisibleItem<Item> {
  let item: Item
  let anchor: Anchor<CGRect>
}

extension VisibleItem: Equatable where Item: Equatable {}

// https://swiftwithmajid.com/2020/03/18/anchor-preferences-in-swiftui/
struct VisiblePreferenceKey<Item>: PreferenceKey {
  typealias Value = [VisibleItem<Item>]

  // The default is optimized for the detail view, which, for a set of not-too-wide images in a not-too-thin container,
  // will house ~2 images. The sidebar view suffers, storing ~14 images given similar constraints; but the detail view
  // is the most active, so it makes sense to optimize for it.
  static var defaultMinimumCapacity: Int { 4 }

  static var defaultValue: Value {
    Value(minimumCapacity: defaultMinimumCapacity)
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.append(contentsOf: nextValue())
  }
}

struct PreferencePublisherViewModifier<Key, Sub, Pub>: ViewModifier
where Key: PreferenceKey,
      Key.Value: Equatable,
      Sub: Subject<Key.Value, Never>,
      Pub: Publisher<Key.Value, Never> {
  private let defaultValue: Key.Value
  private let key: Key.Type
  private let subject: Sub
  private let publisher: Pub

  @State private var value: Key.Value?

  init(_ key: Key.Type = Key.self, defaultValue: Key.Value, subject: Sub, publisher: Pub) {
    self.key = key
    self.defaultValue = defaultValue
    self.subject = subject
    self.publisher = publisher
  }

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(key) { value in
        subject.send(value)
      }
      .onReceive(publisher) { value in
        self.value = value
      }
      .preference(key: key, value: value ?? defaultValue)
  }
}

extension View {
  func preferencePublisher<Key, Sub, Pub>(
    _ key: Key.Type = Key.self,
    defaultValue value: Key.Value,
    subject: Sub,
    publisher: Pub
  ) -> some View where Key: PreferenceKey,
                       Key.Value: Equatable,
                       Sub: Subject<Key.Value, Never>,
                       Pub: Publisher<Key.Value, Never> {
    self.modifier(PreferencePublisherViewModifier(key, defaultValue: value, subject: subject, publisher: publisher))
  }
}
