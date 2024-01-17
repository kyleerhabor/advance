//
//  ImageCollectionCopyingView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/27/23.
//

import Defaults
import Algorithms
import OSLog
import SwiftUI

struct ImageCollectionCopyingView: View {
  @Environment(CopyDepot.self) private var depot
  @Default(.resolveCopyingConflicts) private var resolveConflicts

  @Binding var isPresented: Bool
  @Binding var error: String?
  let action: (URL) -> Void

  var body: some View {
    Menu("Copy to Folder") {
      ForEach(depot.main) { destination in
        Button {
          action(destination.url)
        } label: {
          Text(destination.string)
        }
      }
    } primaryAction: {
      isPresented.toggle()
    }
  }

  // TODO: Figure out a good design for extracting the duplicated file exists checks.
  static func saving(action: () throws -> Void) rethrows {
    do {
      try action()
    } catch let err as CocoaError where err.code == .fileWriteFileExists {
      throw err
    } catch {
      // Ignored (TODO: remember why)
    }
  }

  static func saving(url scope: some URLScope, to destination: URL, action: (URL) throws -> Void) rethrows {
    let url = scope.url

    do {
      try action(url)
    } catch let err as CocoaError where err.code == .fileWriteFileExists {
      throw err
    } catch {
      Logger.ui.error("Could not copy image \"\(url.string)\" to destination \"\(destination.string)\": \(error)")

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

  static func normalize(url: URL) -> URL {
    let matchers = [Matcher.trash, Matcher.home, Matcher.volumeTrash, Matcher.volume]

    return matchers.reduce(url) { url, matcher in
      matcher.match(items: url.pathComponents) ?? url
    }
  }
}
