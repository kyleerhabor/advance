//
//  ImageCollectionCopyDestinationView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/27/23.
//

import OSLog
import SwiftUI

struct ImageCollectionCopyDestinationView<Scope>: View where Scope: URLScope {
  @Environment(CopyDepot.self) private var depot

  @Binding var isPresented: Bool
  @Binding var error: String?
  let scopes: () -> [Scope]

  var body: some View {
    Menu("Copy to Folder", systemImage: "doc.on.doc") {
      ForEach(depot.resolved, id: \.url) { destination in
        Button {
          do {
            try Self.save(scopes: scopes(), to: destination.url)
          } catch {
            self.error = error.localizedDescription
          }
        } label: {
          Text(destination.path)
        }
      }
    } primaryAction: {
      isPresented.toggle()
    }
  }

  static func save(scopes: [Scope], to destination: URL) throws {
    do {
      try destination.scoped {
        try scopes.forEach { scope in
          let url = scope.url

          do {
            try scope.scoped {
              try FileManager.default.copyItem(at: url, to: destination.appending(component: url.lastPathComponent))
            }
          } catch {
            if let err = error as? CocoaError, err.code == .fileWriteFileExists {
              throw error
            }

            Logger.ui.info("Could not copy image \"\(url.string)\" to destination \"\(destination.string)\": \(error)")

            throw error
          }
        }
      }
    } catch {
      guard let err = error as? CocoaError,
            err.code == .fileWriteFileExists else {
        return
      }

      throw error
    }
  }
}
