//
//  Scened.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/28/23.
//

import SwiftUI
import VisionKit

struct DeferredScene<Content>: Scene where Content: Scene {
  typealias Action = () -> Void

  @State private var first = false
  let action: Action
  let content: Content

  var body: some Scene {
    content
      .onChange(of: true, initial: true) {
        Task {
          first = true
        }
      }.onChange(of: first) {
        Task {
          if first {
            first.toggle()

            return
          }

          action()
        }
      }
  }
}

extension Scene {
  func deferred(action: @escaping DeferredScene<Self>.Action) -> some Scene {
    DeferredScene(action: action, content: self)
  }
}
