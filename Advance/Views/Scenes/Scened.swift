//
//  Scened.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/28/23.
//

import AdvanceCore
import SwiftUI

struct DeferredScene<Content>: Scene where Content: Scene {
  typealias Action = () -> Void

  @State private var countup = 0
  let count: Int
  let action: Action
  let content: Content

  var body: some Scene {
    content.onChange(of: countup, initial: true) {
      Task {
        if countup < count {
          countup = countup.incremented()

          return
        }

        action()
      }
    }
  }
}

extension Scene {
  func deferred(count: Int, action: @escaping DeferredScene<Self>.Action) -> some Scene {
    DeferredScene(count: count, action: action, content: self)
  }
}
