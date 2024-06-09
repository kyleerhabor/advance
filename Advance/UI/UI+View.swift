//
//  UI+View.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/9/24.
//

import Combine
import SwiftUI

struct PreferencePublisherViewModifier<Value, Key, Sub, Pub>: ViewModifier
where Value: Equatable,
      Key: PreferenceKey, Key.Value == Value,
      Sub: Subject<Value, Never>,
      Pub: Publisher<Value, Never> {
  private let defaultValue: Value
  private let key: Key.Type
  private let subject: Sub
  private let publisher: Pub

  @State private var value: Value?

  init(_ key: Key.Type = Key.self, defaultValue: Value, subject: Sub, publisher: Pub) {
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
  func preferencePublisher<Value, Key, Sub, Pub>(
    _ key: Key.Type = Key.self,
    defaultValue value: Value,
    subject: Sub,
    publisher: Pub
  ) -> some View where Value: Equatable,
                       Key: PreferenceKey, Key.Value == Value,
                       Sub: Subject<Value, Never>,
                       Pub: Publisher<Value, Never> {
    self.modifier(PreferencePublisherViewModifier(key, defaultValue: value, subject: subject, publisher: publisher))
  }
}
