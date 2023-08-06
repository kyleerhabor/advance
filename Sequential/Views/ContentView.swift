//
//  ContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import SwiftUI

struct ContentView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  @State private var present = false

  var body: some View {
    Button("Select...") {
      present.toggle()
    }.fileImporter(isPresented: $present, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
      guard case let .success(urls) = result,
            let pUrls = try? urls.map({ try PersistentURL($0) }) else {
        return
      }

      // We're getting one step closer to being able to axe this whole window! We still can't just toggle present in
      // .onAppear since the window will still be visible in the back.
      withTransaction(\.dismissBehavior, .destructive) {
        dismissWindow(id: "app")
        openWindow(value: Sequence(from: pUrls))
      }
    }
  }
}

#Preview {
  ContentView()
}
