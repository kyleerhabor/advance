//
//  SizeView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/2/24.
//

import Combine
import OSLog
import SwiftUI

struct SizeView<Sub, Pub>: View where Sub: Subject<CGSize, Never>,
                                      Pub: Publisher<CGSize, Never> {
  let subject: Sub
  let publisher: Pub
  let action: (CGSize) async -> Void

  @State private var size: CGSize?

  var body: some View {
    GeometryReader { proxy in
      Color.clear
        .onChange(of: proxy.size) {
          subject.send(proxy.size)
        }
        // TODO: Document behavior.
        .task(id: size) {
          let size = proxy.size

          guard size != .zero else {
            return
          }

          await action(size)
        }
    }
    .onReceive(publisher) { size in
      self.size = size
    }
  }
}
