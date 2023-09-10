//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import OSLog
import SwiftUI

enum ImageError: Error {
  case undecodable
}

struct Size: Hashable {
  let width: Int
  let height: Int

  var aspectRatio: Double {
    let width = Double(width)
    let height = Double(height)

    return width / height
  }

  var area: Int {
    width * height
  }
}

func reversedImage(properties: Dictionary<CFString, Any>) -> Bool? {
  guard let raw = properties[kCGImagePropertyOrientation] as? UInt32,
        let orientation = CGImagePropertyOrientation(rawValue: raw) else {
    return nil
  }

  // TODO: Cover other orientations.
  return orientation == .right
}

extension NavigationSplitViewVisibility: RawRepresentable {
  public typealias RawValue = Int

  public init?(rawValue: RawValue) {
    switch rawValue {
      case 0: self = .all
      case 1: self = .detailOnly
      default: return nil
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .all: 0
      case .detailOnly: 1
      default: -1
    }
  }
}

enum URLError: Error {
  case inaccessibleSecurityScope
}

struct Keys {
  static let margin = Item("margin", 1)
  static let appearance = Item("appearance", nil as SettingsView.Scheme)
  // I think enabling Live Text by default but disabling the icons strikes a nice compromise between convenience (e.g.
  // being able to select text) and UI simplicity (i.e. not having the buttons get in the way).
  static let liveText = Item("liveText", true)
  static let liveTextIcon = Item("liveTextIcon", false)
  static let hideWindowSidebar = Item("hideWindowSidebar", false)
  static let collapseMargins = Item("collapseMargins", true)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}

enum ExecutionError: Error {
  case interrupt
}

struct CopyDepotBookmark: Codable {
  let data: Data
  let url: URL
  let resolved: Bool

  init(data: Data, url: URL, resolved: Bool = false) {
    self.data = data
    self.url = url
    self.resolved = resolved
  }

  func resolve() throws -> Self {
    var data = data
    var resolved = try ResolvedBookmark(from: data)

    if resolved.stale {
      let url = resolved.url
      data = try url.scoped { try url.bookmark(options: .withSecurityScope) }
      resolved = try ResolvedBookmark(from: data)
    }

    return .init(data: data, url: resolved.url, resolved: true)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
      data: try container.decode(Data.self, forKey: .data),
      url: try container.decode(URL.self, forKey: .url)
    )
  }

  enum CodingKeys: CodingKey {
    case data, url
  }
}

struct CopyDepotURL {
  let url: URL
  let path: AttributedString
  let icon: Image
}

@Observable
// I tried writing a @DataStorage property wrapper to act like @AppStorage but specifically for storing Data types
// automatically (via Codable conformance), but had trouble reflecting changes across scenes. In addition, changes
// would only get communicated to the property wrapper on direct assignment (making internal mutation not simple)
class CopyDepot {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var bookmarks = [CopyDepotBookmark]()
  var resolved = [CopyDepotURL]()
  var unresolved = [CopyDepotURL]()

  func resolve() {
    guard let data = UserDefaults.standard.data(forKey: "copyDestinations") else {
      Logger.model.info("No data for copy destinations found in user defaults")

      return
    }

    do {
      self.bookmarks = try decoder
        .decode([CopyDepotBookmark].self, from: data)
        .map { bookmark in
          do {
            return try bookmark.resolve()
          } catch {
            guard let err = error as? CocoaError,
                  err.code == .fileNoSuchFile || err.code == .fileReadCorruptFile else {
              Logger.model.error("Bookmark for copy destination \"\(bookmark.url)\" (\(bookmark.data)) could not be resolved: \(error)")

              return bookmark
            }

            Logger.model.info("Bookmark for copy destination \"\(bookmark.url)\" (\(bookmark.data)) could not be resolved. Is it temporarily unavailable?")

            return bookmark
          }
        }

      update()
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func urls(from urls: [URL]) -> [CopyDepotURL] {
    let index = Set(urls)

    return urls.map { url in
      var index = index
      index.remove(url)

      let path = path(
        of: url,
        considering: index
      ).joined(separator: " 􀰇 ")

      var attr = AttributedString(path)

      if let range = attr.range(of: "􀰇") {
        attr[range].foregroundColor = .tertiaryLabel
      }

      return .init(
        url: url,
        path: attr,
        icon: Image(nsImage: NSWorkspace.shared.icon(forFile: url.string))
      )
    }
  }

  func update() {
    resolved = urls(from: bookmarks.filter(\.resolved).map(\.url))
    unresolved = urls(from: bookmarks.filter { !$0.resolved }.map(\.url))
  }

  func store() {
    do {
      let data = try encoder.encode(bookmarks)

      UserDefaults.standard.set(data, forKey: "copyDestinations")
    } catch {
      Logger.model.error("\(error)")
    }
  }

  private func path(of url: URL, considering urls: Set<URL>) -> [String] {
    guard !urls.isEmpty else {
      return [url.lastPathComponent]
    }

    let components = url.pathComponents
    let paths = Array(components.reversed())
    var remaining = urls.map { $0.pathComponents.dropLast(0) }
    var result = [String]()

    // Very crude, but works.
    for path in paths {
      if remaining.isEmpty {
        // If, on an e.g. removable volume, the path refers to a URL in the user-separated trash (e.g. "/Volumes/T7/.Trashes/<uid>/Three Days of Happiness"),
        // rewrite that segment to be more user-friendly.
        if Int(result.last!) != nil && path == ".Trashes" {
          result.removeLast()
          result.append("Trash")
        }

        return result.reversed()
      }

      remaining = remaining
        .filter { $0.last == path }
        .map { $0.dropLast() }

      result.append(path)
    }

    return result.reversed()
  }
}
