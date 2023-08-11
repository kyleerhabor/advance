//
//  ContentView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import SwiftUI
import OSLog

struct ContentView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  @State private var present = false

  var body: some View {
    Button("Select...") {
      present.toggle()
    }.fileImporter(isPresented: $present, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
      guard case let .success(urls) = result else {
        return
      }

      // We're getting one step closer to being able to axe this whole window! We still can't just toggle present in
      // .onAppear since the window will still be visible in the back.
      withTransaction(\.dismissBehavior, .destructive) {
        do {
          let bookmarks = try urls.map { try $0.bookmark() }

          dismissWindow(id: "app")
          openWindow(value: Sequence(bookmarks: bookmarks))
        } catch {
          Logger.ui.error("\(error)")
        }
      }
    }
  }
}

#Preview {
  ContentView()
}
