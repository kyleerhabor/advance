//
//  ImageCollectionCopyingView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/27/23.
//

import AdvanceCore
import Algorithms
import OSLog
import SwiftUI

struct ImageCollectionCopyingView: View {
  @Environment(CopyDepot.self) private var depot

  @Binding var isPresented: Bool
  let action: (URL) -> Void

  var body: some View {
    Menu("Images.Copying.Action") {
      ForEach(depot.main) { destination in
        Button {
          action(destination.url)
        } label: {
          Text(destination.string)
        }
      }
    } primaryAction: {
      isPresented = true
    }
  }

  // TODO: Figure out a good design for extracting the duplicated file exists checks.
  nonisolated static func saving(action: () throws -> Void) rethrows {
    do {
      try action()
    } catch let err as CocoaError where err.code == .fileWriteFileExists {
      throw err
    } catch {
      // Ignored (we only handle conflicts)
    }
  }

  nonisolated static func saving(url scope: some SecurityScopedResource, to destination: URL, action: (URL) throws -> Void) rethrows {
//    let url = scope.url
//
//    do {
//      try action(url)
//    } catch let err as CocoaError where err.code == .fileWriteFileExists {
//      throw err
//    } catch {
//      Logger.ui.error("Could not copy image \"\(url.pathString)\" to destination \"\(destination.path)\": \(error)")
//
//      throw error
//    }
  }

  nonisolated static func save(url: URL, to destination: URL, resolvingConflicts resolveConflicts: Bool) throws {
    do {
      try FileManager.default.copyItem(at: url, to: destination.appending(component: url.lastPathComponent))
    } catch {
      guard let err = error as? CocoaError, err.code == .fileWriteFileExists else {
        Logger.ui.info("Could not copy image \"\(url.pathString)\" to destination \"\(destination.path)\": \(error)")

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

  nonisolated static func save(resolving url: URL, to destination: URL) throws -> Bool {
    let resolutions = Self.normalize(url: url)
      .pathComponents
      .dropFirst() // "/"
      .dropLast() // The path we initially tried (e.g. "image" from "image.jpeg")
      .reversed()
      .reductions(into: []) { $0.append($1) }
      .dropFirst() // The initial value from the reduction (an empty array)

    return try resolutions.map { resolution in
      let out = "\(url.lastPath) [\(resolution.joined(separator: " 􀯶 "))]"

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

  nonisolated static func normalize(url: URL) -> URL {
    url
  }
}
