//
//  ScrollingView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 11/20/23.
//

import Combine
import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue = CGPoint.zero

  static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    let next = nextValue()

    guard next != .zero else {
      return
    }

    value = next
  }
}

struct ScrollingListViewModifier: ViewModifier {
  private let subject = PassthroughSubject<ScrollOffsetPreferenceKey.Value, Never>()
  private let publisher: AnyPublisher<ScrollOffsetPreferenceKey.Value, Never>

  @Binding var scrolling: Bool

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
        subject.send(offset)
      }.onReceive(publisher) { _ in
        scrolling.toggle()
      }
  }

  init(scrolling: Binding<Bool>) {
    self._scrolling = scrolling

    publisher = subject
      .collect(6)
      .filter { origins in
        origins.dropFirst().allSatisfy { $0.x == origins.first?.x }
      }
      .compactMap { $0.first }
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}

extension View {
  func listScrolling(_ scrolling: Binding<Bool>) -> some View {
    self.modifier(ScrollingListViewModifier(scrolling: scrolling))
  }
}
