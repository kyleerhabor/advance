//
//  CopyDepot.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/27/23.
//

import OSLog
import SwiftUI

struct CopyDepotBookmark: Codable {
  let data: Data
  let url: URL
  let resolved: Bool

  init(data: Data, url: URL, resolved: Bool) {
    self.data = data
    self.url = url
    self.resolved = resolved
  }

  func resolve() throws -> Bookmark {
    try .init(data: data, resolving: .withSecurityScope) { url in
      try url.scoped {
        try url.bookmark(options: .withSecurityScope)
      }
    }
  }

  // MARK: Codable conformance

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let data = try container.decode(Data.self, forKey: .data)
    let url = try container.decode(URL.self, forKey: .url)

    self.init(data: data, url: url, resolved: false)
  }

  enum CodingKeys: CodingKey {
    case data, url
  }
}

struct CopyDepotDestination {
  let url: URL
  let path: AttributedString
  let icon: Image
}

extension CopyDepotDestination: Identifiable {
  var id: URL { url }
}

@Observable
// I tried writing a @DataStorage property wrapper to act like @AppStorage but specifically for storing Data types
// automatically (via Codable conformance), but had trouble reflecting changes across scenes. In addition, changes
// would only get communicated to the property wrapper on direct assignment (making internal mutation not simple)
class CopyDepot {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var bookmarks = [CopyDepotBookmark]()
  var resolved = [CopyDepotDestination]()
  var unresolved = [CopyDepotDestination]()

  func resolve() async -> [CopyDepotBookmark] {
    guard let data = UserDefaults.standard.data(forKey: "copyDestinations") else {
      Logger.model.info("No data for copy destinations found in user defaults")

      return []
    }

    do {
      let bookmarks = try decoder
        .decode([CopyDepotBookmark].self, from: data)
        .map { bookmark in
          do {
            let bookmark = try bookmark.resolve()

            return CopyDepotBookmark(
              data: bookmark.data,
              url: bookmark.url,
              resolved: true
            )
          } catch {
            let path = bookmark.url.string

            if let err = error as? CocoaError, err.code == .fileNoSuchFile || err.code == .fileReadCorruptFile {
              Logger.model.info("Bookmark for copy destination \"\(path)\" (\(bookmark.data)) could not be resolved. Is it temporarily unavailable?")
            } else {
              Logger.model.error("Bookmark for copy destination \"\(path)\" (\(bookmark.data)) could not be resolved: \(error)")
            }

            // We want to keep it for "unresolved" bookmarks (allowing the user to remove it in case).
            return bookmark
          }
        }.sorted { $0.url < $1.url }

      return bookmarks
    } catch {
      Logger.model.error("Could not decode bookmarks: \(error)")

      return []
    }
  }

  func update() {
    let grouping = Dictionary(grouping: bookmarks, by: \.resolved)
    let resolved = grouping[true] ?? []
    let unresolved = grouping[false] ?? []
    let home = URL.homeDirectory.pathComponents.prefix(3)

    self.resolved = resolved.map { compute(url: $0.url, home: home) }
    self.unresolved = unresolved.map { compute(url: $0.url, home: home) }
  }

  func store() {
    do {
      let data = try encoder.encode(bookmarks)

      UserDefaults.standard.set(data, forKey: "copyDestinations")
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func compute(url: URL, home homeComponents: ArraySlice<String>) -> CopyDepotDestination {
    let components = url.pathComponents

    // This whole thing is a mess, but is much better than my prior implementation.
    let home = components.count > homeComponents.count && zip(components, homeComponents).allSatisfy { (component, home) in
      component == home
    }

    let dropping = home ? homeComponents.count : 1
    let paths = components.dropFirst(dropping)

    var separator = AttributedString(" 􀰇 ")
    separator.foregroundColor = .tertiaryLabelColor

    var string = AttributedString()
    var iterator = paths
      .map { AttributedString($0) }
      .makeIterator()

    if let first = iterator.next() {
      string.append(first)

      while let next = iterator.next() {
        string.append(separator)
        string.append(next)
      }
    }

    return .init(
      url: url,
      path: string,
      icon: .init(nsImage: NSWorkspace.shared.icon(forFile: url.string))
    )
  }
}
