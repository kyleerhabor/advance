//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import ImageIO
import OSLog
import SwiftUI

enum StorageKeys: String {
  case fullWindow
  case margin
  case sidebar
  case appearance
}

enum ImageError: Error {
  case undecodable, lost
}

class Bookmark: Codable {
  var data: Data
  var url: URL?

  init(data: Data, url: URL? = nil) {
    self.data = data
    self.url = url
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.data = try container.decode(Data.self)
  }

  func resolved() throws -> (Bool, URL) {
    var stale = false
    let resolved = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)

    return (stale, resolved)
  }

  func resolve() throws {
    // Interesting findings in Instruments:
    // - Resolving bookmarks is slow
    // - Extracting the width and height from an image can be slow, but relative to resolving bookmarks, not by much.
    //
    // I tried refactoring SeqImage to only load the URL when a view appears, but this involved making SeqImage
    // a class and adding a resolve method. To put it shortly, @Observable kept complaining about modifying the layout
    // engine from concurrent threads, and I couldn't be bothered to figure out exactly why. It wasn't exactly in zero
    // vain, however, since `bookmarks` is now directly an Array of bookmarks (rather than a wrapped class) and the
    // aspect ratio is directly derived (since no view actually uses its separate values).
    var (stale, url) = try resolved()

    if stale {
      data = try url.scoped { try url.bookmarkData() }
      url = try resolved().1
    }

    self.url = url
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    try container.encode(data)
  }
}

extension Bookmark: Hashable {
  static func ==(lhs: Bookmark, rhs: Bookmark) -> Bool {
    lhs.data == rhs.data
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(data)
  }
}

// For some reason, conforming to Transferable and declaring the support for UTType.image is not enough to support .dropDestination(...)
struct SeqImage: Codable {
  var url: URL
  let aspectRatio: Double

  // TODO: Make this non-failable.
  //
  // I couldn't get Image I/O to read the resolved bookmark when it was explicitly created with the .withSecurityScope
  // option. Currently, the image will just be dropped from the UI if this fails, but I'd like to get it working, since
  // things like moving files to different locations are not supported.
  init?(url: URL) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? Dictionary<CFString, Any> else {
      return nil
    }

    let width = Double(properties[kCGImagePropertyPixelWidth] as! Int)
    let height = Double(properties[kCGImagePropertyPixelHeight] as! Int)

    self.url = url
    self.aspectRatio = width / height
  }
}

@Observable
class Seq: Codable {
  var images = [SeqImage]()
  var bookmarks: [Bookmark]

  init(bookmarks: [Data]) {
    self.bookmarks = bookmarks.map { .init(data: $0) }
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.bookmarks = try container.decode([Bookmark].self)
  }

  func load() {
    do {
      self.images = try bookmarks.compactMap { bookmark in
        try bookmark.resolve()

        return SeqImage(url: bookmark.url!)
      }
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func move(from source: IndexSet, to destination: Int) {
    bookmarks.move(fromOffsets: source, toOffset: destination)
    images.move(fromOffsets: source, toOffset: destination)
  }

  func insert(_ urls: [URL], at offset: Int, scoped: Bool) -> Bool {
    do {
      let images = try urls.compactMap { url in
        if scoped {
          try url.scoped { SeqImage(url: url) }
        } else {
          SeqImage(url: url)
        }
      }

      guard !images.isEmpty else {
        return false
      }

      let bookmarks = try images.map { image in
        let url = image.url
        let data = try scoped
          ? url.scoped { try url.bookmarkData() }
          : url.bookmarkData()

        return Bookmark(data: data, url: url)
      }

      self.bookmarks.insert(contentsOf: bookmarks, at: offset)
      self.images.insert(contentsOf: images, at: offset)

      return true
    } catch {
      Logger.ui.error("\(error)")

      return false
    }
  }

  func delete(_ urls: Set<URL>) {
    bookmarks.removeAll { bookmark in
      guard let url = bookmark.url else {
        return false
      }

      return urls.contains(url)
    }

    images.removeAll { urls.contains($0.url) }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(bookmarks)
  }
}

extension Seq: Hashable {
  static func ==(lhs: Seq, rhs: Seq) -> Bool {
    lhs.bookmarks == rhs.bookmarks
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(bookmarks)
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

func resampleImage(at url: URL, forSize size: CGSize) async -> Image? {
  let options: [CFString : Any] = [
    // We're not going to use kCGImageSourceShouldAllowFloat here since the sizes can get very precise.
    kCGImageSourceShouldCacheImmediately: true,
    // For some reason, resizing images with kCGImageSourceCreateThumbnailFromImageIfAbsent sometimes uses a
    // significantly smaller pixel size than specified with kCGImageSourceThumbnailMaxPixelSize. For example, I have a
    // copy of Mikuni Shimokaway's album "all the way" (https://musicbrainz.org/release/19a73c6d-8a11-4851-bb3b-632bcd6f1adc)
    // with scanned images. Even though the first image's size is 800x677 and I set the max pixel size to 802 (since
    // it's based on the view's size), it sometimes returns 160x135. This is made even worse by how the view refuses to
    // update to the next created image. This behavior seems to be predicated on the given max pixel size, given a
    // larger image did not trigger the behavior (but did in one odd case).
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
    kCGImageSourceCreateThumbnailWithTransform: true
  ]

  // There seems to be a memory leak somewhere (at least, sometimes).
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
    return nil
  }

  Logger.model.info("Created a resampled image from \"\(url)\" at dimensions \(image.width.description)x\(image.height.description) for size \(size.width) / \(size.height)")

  return Image(nsImage: .init(cgImage: image, size: size))
    .resizable()
}

enum URLError: Error {
  case inaccessibleSecurityScope
}
