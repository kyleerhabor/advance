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

enum TitleBarVisibility {
  case visible, invisible
}

enum ImageError: Error {
  case undecodable, lost
}

struct SequenceImage: Codable {
  var url: URL
  let aspectRatio: Double

  init(url: URL) throws {
    self.url = url

    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! Dictionary<CFString, Any>
    let width = Double(properties[kCGImagePropertyPixelWidth] as! Int)
    let height = Double(properties[kCGImagePropertyPixelHeight] as! Int)

    self.aspectRatio = width / height
  }
}

@Observable
class Sequence: Codable {
  var images = [SequenceImage]()
  var bookmarks: [Data]

  init(bookmarks: [Data]) {
    self.bookmarks = bookmarks
  }

  func load() async {
    var images = [SequenceImage]()

    // Interesting findings in Instruments:
    // - Resolving bookmarks is slow
    // - Extracting the width and height from an image can be slow, but relative to resolving bookmarks, not by much.
    //
    // I tried refactoring SequenceImage to only load the URL when a view appears, but this involved making SequenceImage
    // a class and adding a resolve method. To put it shortly, @Observable kept complaining about modifying the layout
    // engine from concurrent threads, and I couldn't be bothered to figure out exactly why. It wasn't exactly in zero
    // vain, however, since `bookmarks` is now directly an Array of bookmarks (rather than a wrapped class) and the
    // aspect ratio is directly derived (since no view actually uses its separate values).
    do {
      for (index, var bookmark) in bookmarks.enumerated() {
        var isStale = false
        var resolved = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)

        if isStale {
          bookmark = try resolved.bookmark()
          bookmarks[index] = bookmark
        }

        resolved = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)

        images.append(try SequenceImage(url: resolved))
      }
      
      self.images = images
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func move(from source: IndexSet, to destination: Int) {
    bookmarks.move(fromOffsets: source, toOffset: destination)
    images.move(fromOffsets: source, toOffset: destination)
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.bookmarks = try container.decode([Data].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(bookmarks)
  }
}

extension Sequence: Hashable {
  static func ==(lhs: Sequence, rhs: Sequence) -> Bool {
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
    // update to the next created image.
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
    kCGImageSourceCreateThumbnailWithTransform: true
  ]

  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
    return nil
  }

  Logger.model.info("Created a resampled image from \"\(url)\" at dimensions \(image.width.description)x\(image.height.description) for size \(size.width) / \(size.height)")

  return Image(nsImage: .init(cgImage: image, size: size))
}

enum URLError: Error {
  case inaccessibleSecurityScope
}
