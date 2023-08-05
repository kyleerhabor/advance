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

      // This makes closing the current window work, but is kind of a hack. It also has an obvious delay which isn't
      // present in the "Open..." menu item. Calling NSApp.keyWindow?.close() explicitly has the same effect, meanwhile.
      Task {
        dismissWindow(id: "app")
        openWindow(value: Sequence(from: pUrls))
      }
    }
  }
}

#Preview {
  ContentView()
}
