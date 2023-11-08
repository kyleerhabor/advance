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
  @Binding var error: String?

  let scopes: () -> [Scope]

  var body: some View {
    Menu("Copy to Folder", systemImage: "doc.on.doc") {
      ForEach(depot.resolved, id: \.url) { destination in
        Button {
          let dest = destination.url

          do {
            try dest.scoped {
              try scopes().forEach { scope in
                let url = scope.url

                do {
                  try scope.scoped {
                    try FileManager.default.copyItem(at: url, to: dest.appending(component: url.lastPathComponent))
                  }
                } catch {
                  guard let err = error as? CocoaError,
                        err.code == .fileWriteFileExists else {
                    Logger.ui.info("Could not copy image \"\(url.string)\" to destination \"\(dest.string)\": \(error)")

                    throw error
                  }

                  throw error
                }
              }
            }
          } catch {
            guard let err = error as? CocoaError,
                  err.code == .fileWriteFileExists else {
              return
            }

            self.error = error.localizedDescription
          }
        } label: {
          Text(destination.path)
        }
      }
    }
  }
}
