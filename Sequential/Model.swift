//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import OSLog
import SwiftUI

struct ResolvedBookmark {
  let url: URL
  let stale: Bool

  init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo document: URL? = nil
  ) throws {
    var stale = false

    self.url = try URL(resolvingBookmarkData: data, options: options, relativeTo: document, bookmarkDataIsStale: &stale)
    self.stale = stale
  }
}

struct Bookmark {
  let data: Data
  let url: URL
}

extension Bookmark {
  init(
    data: Data,
    resolving: URL.BookmarkResolutionOptions,
    relativeTo document: URL? = nil,
    create: (URL) throws -> Data
  ) throws {
    var data = data
    var resolved = try ResolvedBookmark(data: data, options: resolving, relativeTo: document)

    if resolved.stale {
      // From the resolution options, we can infer that if it includes .withSecurityScope, wrapping URL in the method
      // with the same name would theoretically be valid, but we still wouldn't exactly know *how* to create the
      // bookmark. Personally, I think accepting a closure and having the caller handle the case maintains simplicity.
      // If we did check for the security scope and implicity wrap create in one, the user would need to implicitly
      // track it, which would be more complex.
      data = try create(resolved.url)
      resolved = try ResolvedBookmark(data: data, options: resolving, relativeTo: document)
    }

    self.init(data: data, url: resolved.url)
  }
}

enum ImageError: Error {
  case undecodable
  case thumbnail
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

enum ExecutionError: Error {
  case interrupt
}

struct Keys {
  static let appearance = Item("appearance", nil as SettingsView.Scheme)
  static let margin = Item("margin", 1)
  static let collapseMargins = Item("collapseMargins", true)
  static let windowless = Item("windowless", false)
  static let displayTitleBarImage = Item("displayTitleBarImage", true)
  // I think enabling Live Text by default but disabling the icons strikes a nice compromise between convenience (e.g.
  // being able to select text) and UI simplicity (i.e. not having the buttons get in the way).
  static let liveText = Item("liveText", true)
  static let liveTextIcon = Item("liveTextIcon", false)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}
