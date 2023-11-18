//
//  ImageCollectionCopyDestinationView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/27/23.
//

import Algorithms
import OSLog
import SwiftUI

struct ImageCollectionCopyDestinationView<Scope>: View where Scope: URLScope {
  @Environment(CopyDepot.self) private var depot
  @AppStorage(Keys.resolveCopyDestinationConflicts.key) private var resolveConflicts = Keys.resolveCopyDestinationConflicts.value

  @Binding var isPresented: Bool
  @Binding var error: String?
  let scopes: () -> [Scope]

  var body: some View {
    Menu("Copy to Folder", systemImage: "doc.on.doc") {
      ForEach(depot.resolved, id: \.url) { destination in
        Button {
          // If the user is copying a large collection, we could benefit from displaying a progress indicator in the
          // toolbar.
          Task {
            do {
              try await save(to: destination.url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        } label: {
          Text(destination.path)
        }
      }
    } primaryAction: {
      isPresented.toggle()
    }
  }

  func save(to destination: URL) async throws {
    try Self.saving {
      try destination.scoped {
        try scopes().forEach { scope in
          try Self.saving(url: scope, to: destination) { url in
            try scope.scoped {
              try Self.save(url: url, to: destination, resolvingConflicts: resolveConflicts)
            }
          }
        }
      }
    }
  }

  // TODO: Figure out a good design for extracting the duplicated file exists checks.
  static func saving(action: () throws -> Void) rethrows {
    do {
      try action()
    } catch {
      if let err = error as? CocoaError, err.code == .fileWriteFileExists {
        throw error
      }
    }
  }

  static func saving(url scope: Scope, to destination: URL, action: (URL) throws -> Void) rethrows {
    let url = scope.url

    do {
      try action(url)
    } catch {
      if let err = error as? CocoaError, err.code == .fileWriteFileExists {
        throw error
      }

      Logger.ui.info("Could not copy image \"\(url.string)\" to destination \"\(destination.string)\": \(error)")

      throw error
    }
  }

  static func save(url: URL, to destination: URL, resolvingConflicts resolveConflicts: Bool) throws {
    do {
      try FileManager.default.copyItem(at: url, to: destination.appending(component: url.lastPathComponent))
    } catch {
      guard let err = error as? CocoaError, err.code == .fileWriteFileExists else {
        Logger.ui.info("Could not copy image \"\(url.string)\" to destination \"\(destination.string)\": \(error)")

        throw error
      }

      guard resolveConflicts else {
        throw error
      }

      if !(try save(resolving: url, to: destination)) {
        throw error
      }
    }
  }

  static func save(resolving url: URL, to destination: URL) throws -> Bool {
    let resolutions = Self.normalize(url: url)
      .pathComponents
      .dropFirst() // "/"
      .dropLast() // The path we initially tried (e.g. "image" from "image.jpeg")
      .reversed()
      .reductions(into: []) { $0.append($1) }
      .dropFirst() // The initial value from the reduction (an empty array)

    return try resolutions.map { resolution in
      let out = "\(url.deletingPathExtension().lastPathComponent) [\(resolution.joined(separator: " 􀯶 "))]"

      return destination
        .appending(component: out)
        .appendingPathExtension(url.pathExtension)
    }.contains { dest in
      do {
        try FileManager.default.copyItem(at: url, to: dest)
      } catch {
        guard let err = error as? CocoaError, err.code == .fileWriteFileExists else {
          throw error
        }

        return false
      }

      return true
    }
  }

  static func normalize(url: URL) -> URL {
    let matchers = [Matcher.trash, Matcher.home, Matcher.volumeTrash, Matcher.volume]

    return matchers.reduce(url) { url, matcher in
      matcher.match(items: url.pathComponents) ?? url
    }
  }
}
