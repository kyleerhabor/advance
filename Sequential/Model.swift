//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import ImageIO
import OSLog
import SwiftUI

struct BookmarkURL {
  let url: URL
  let isStale: Bool

  init(from bookmark: Data) throws {
    var isStale = false

    self.url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    self.isStale = isStale
  }
}

enum PersistentURLError: Error {
  case inaccessibleSecurityScope
}

struct PersistentURL: Hashable, Codable {
  var bookmark: Data

  init(_ url: URL) throws {
    self.bookmark = try Self.createBookmark(for: url)
  }

  static func createBookmark(for url: URL) throws -> Data {
    guard url.startAccessingSecurityScopedResource() else {
      throw PersistentURLError.inaccessibleSecurityScope
    }

    let bookmark = try url.bookmarkData()

    url.stopAccessingSecurityScopedResource()

    return bookmark
  }

  mutating func resolve() throws -> URL {
    let bookmarked = try BookmarkURL(from: bookmark)

    guard bookmarked.isStale else {
      return bookmarked.url
    }

    // Per the documentation: "Your app should create a new bookmark ***using the returned URL*** and use it in place of any stored copies of the existing bookmark."
    //
    // "it" clearly refers to the bookmark, but "using the returned URL" is a bit vague without emphasis (which they
    // don't include). I'm not sure if it is a requirement, but better safe than sorry?
    bookmark = try Self.createBookmark(for: bookmarked.url)

    // If the bookmark is still stale, then I don't know what problem we're in.
    return try BookmarkURL(from: bookmark).url
  }
}

enum StorageKeys: String {
  case fullWindow
  case margin
  case sidebar
}

enum TitleBarVisibility {
  case visible, invisible
}

enum ImageError: Error {
  case undecodable
}

struct SequenceImage: Hashable, Codable {
  let url: URL
  let width: Double
  let height: Double
}

@Observable
class Sequence: Codable {
  // TODO: Override the default coders to only encode urls.
  var images = [SequenceImage]()
  var urls: [PersistentURL]

  init(from urls: [PersistentURL]) {
    self.urls = urls
  }

  func load() {
    for var url in urls {
      do {
        let url = try url.resolve()
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as Dictionary
        let width = Double(properties[kCGImagePropertyPixelWidth] as! Int)
        let height = Double(properties[kCGImagePropertyPixelHeight] as! Int)

        self.images.append(.init(
          url: url,
          width: width,
          height: height
        ))
      } catch {
        Logger.model.error("Could not resolve bookmark \"\(url.bookmark, privacy: .public)\": \(error)")
      }
    }
  }

  func move(from source: IndexSet, to destination: Int) {
    urls.move(fromOffsets: source, toOffset: destination)
    images.move(fromOffsets: source, toOffset: destination)
  }
}

extension Sequence: Hashable {
  static func ==(lhs: Sequence, rhs: Sequence) -> Bool {
    lhs.urls == rhs.urls
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.urls.map { $0.bookmark })
  }
}

extension NavigationSplitViewVisibility: RawRepresentable {
  // We could really use a bidirectional map here.
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
