//
//  Schema+Info.swift
//  
//
//  Created by Kyle Erhabor on 6/17/24.
//

import Foundation
import GRDB

// MARK: - Info

public struct ImageInfo {
  let rowID: RowID
  public let data: Data?
  public let hash: Data?
}

extension ImageInfo: Sendable, Decodable {}

extension ImageInfo: Hashable {}

public struct BookmarkInfo {
  let rowID: RowID
  public let data: Data?
  public let options: URL.BookmarkCreationOptions?
  public let hash: Data?

  init(rowID: RowID, data: Data? = nil, options: URL.BookmarkCreationOptions? = nil, hash: Data? = nil) {
    self.rowID = rowID
    self.data = data
    self.options = options
    self.hash = hash
  }

  init(record: BookmarkRecord) {
    self.init(rowID: record.rowID!, data: record.data, options: record.options, hash: record.hash)
  }

  public init(_ info: Self, data: Data? = nil, options: URL.BookmarkCreationOptions? = nil, hash: Data? = nil) {
    self.init(rowID: info.rowID, data: data, options: options, hash: hash)
  }
}

extension BookmarkInfo: Sendable, Decodable {}

extension BookmarkInfo: Equatable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rowID == rhs.rowID
  }
}

extension BookmarkInfo: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.rowID)
  }
}

extension BookmarkInfo: SQLExpressible {
  public var sqlExpression: SQLExpression {
    self.rowID.sqlExpression
  }
}

public struct ImagesImageInfo {
  let rowID: RowID
}

extension ImagesImageInfo: Sendable, Decodable {}

public struct ImagesBookmarkInfo {
  let rowID: RowID
}

extension ImagesBookmarkInfo: Sendable, Decodable {}

public enum ImagesItemTypeInfo: Int {
  case image, bookmark
}

extension ImagesItemTypeInfo: Sendable, Decodable {}

public struct ImagesItemInfo {
  let rowID: RowID
  public let id: UUID?
  public let priority: Int?
  public let isBookmarked: Bool?
  public let type: ImagesItemTypeInfo?
}

extension ImagesItemInfo {
  init(item: ImagesItemRecord) {
    self.init(
      rowID: item.rowID!,
      id: item.id,
      priority: item.priority,
      isBookmarked: item.isBookmarked,
      type: item.type.map { ImagesItemTypeInfo(rawValue: $0.rawValue)! }
    )
  }
}

extension ImagesItemInfo: Sendable, Hashable, Decodable {
  enum CodingKeys: String, CodingKey {
    case rowID, id, priority,
         isBookmarked = "is_bookmarked",
         type
  }
}

extension ImagesItemInfo: SQLExpressible {
  public var sqlExpression: SQLExpression {
    self.rowID.sqlExpression
  }
}

public struct ImagesInfo {
  public typealias ID = UUID

  let rowID: RowID
  public let id: ID?
}

extension ImagesInfo {
  init(_ images: ImagesRecord) {
    self.init(rowID: images.rowID!, id: images.id)
  }
}

extension ImagesInfo: Sendable, Decodable {
  enum CodingKeys: CodingKey {
    case rowID, id
  }
}

extension ImagesInfo: SQLExpressible {
  public var sqlExpression: SQLExpression {
    self.rowID.sqlExpression
  }
}

public struct CopyingInfo {
  let rowID: RowID
  public let id: UUID?
  public let url: URL?
}

extension CopyingInfo {
  init(record: FolderRecord) {
    self.init(rowID: record.rowID!, id: record.id, url: record.url)
  }
}

extension CopyingInfo: Sendable, Decodable {}

extension CopyingInfo: SQLExpressible {
  public var sqlExpression: SQLExpression {
    self.rowID.sqlExpression
  }
}

// MARK: - Response

public struct ImagesIDResponse {
  public let images: ImagesInfo
}

extension ImagesIDResponse: Sendable, Decodable, FetchableRecord {}

public struct BookmarkTrackerResponse {
  public let bookmark: BookmarkInfo
  public let relative: BookmarkInfo?
}

extension BookmarkTrackerResponse: Sendable {}

extension BookmarkTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case bookmark, relative
  }
}

public struct ImagesImageTrackerResponse {
  public let item: ImagesBookmarkInfo
  public let image: ImageInfo?

  public var image2: ImageInfo {
    image!
  }
}

extension ImagesImageTrackerResponse: Sendable {}

extension ImagesImageTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, image
  }
}

public struct ImagesBookmarkTrackerResponse {
  public let item: ImagesBookmarkInfo
  public let bookmark: BookmarkTrackerResponse?

  public var bookmark2: BookmarkTrackerResponse {
    bookmark!
  }
}

extension ImagesBookmarkTrackerResponse: Sendable {}

extension ImagesBookmarkTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, bookmark
  }
}

public struct ImagesItemTrackerResponse {
  public let item: ImagesItemInfo
  public let image: ImagesImageTrackerResponse?
  public let bookmark: ImagesBookmarkTrackerResponse?
}

extension ImagesItemTrackerResponse: Sendable {}

extension ImagesItemTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, image, bookmark
  }
}

public struct ImagesItemsTrackerResponse {
  public let items: [ImagesItemTrackerResponse]
}

extension ImagesItemsTrackerResponse: Sendable {}

extension ImagesItemsTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case items
  }
}

extension ImagesItemsTrackerResponse: FetchableRecord {}

public struct ImagesItemFetchImageResponse {
  public let item: ImagesImageInfo
  public let image: ImageInfo?

  public var image2: ImageInfo {
    image!
  }
}

extension ImagesItemFetchImageResponse: Sendable {}

extension ImagesItemFetchImageResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, image
  }
}

public struct ImagesItemFetchBookmarkSourceResponse {
  public let bookmark: BookmarkInfo
  public let relative: BookmarkInfo?
}

extension ImagesItemFetchBookmarkSourceResponse: Sendable {}

extension ImagesItemFetchBookmarkSourceResponse: Decodable {
  enum CodingKeys: CodingKey {
    case bookmark, relative
  }
}

public struct ImagesItemFetchBookmarkResponse {
  public let item: ImagesBookmarkInfo
  public let bookmark: ImagesItemFetchBookmarkSourceResponse?

  public var bookmark2: ImagesItemFetchBookmarkSourceResponse {
    bookmark!
  }
}

extension ImagesItemFetchBookmarkResponse: Sendable {}

extension ImagesItemFetchBookmarkResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, bookmark
  }
}

public struct ImagesItemFetchResponse {
  public let item: ImagesItemInfo
  public let image: ImagesItemFetchImageResponse?
  public let bookmark: ImagesItemFetchBookmarkResponse?
}

extension ImagesItemFetchResponse: Sendable {}

extension ImagesItemFetchResponse: Decodable {
  enum CodingKeys: CodingKey {
    case item, image, bookmark
  }
}

extension ImagesItemFetchResponse: FetchableRecord {}

public struct ImagesPropertiesTrackerResponse {
  public let images: ImagesInfo
  public let item: ImagesItemInfo
}

extension ImagesPropertiesTrackerResponse: Sendable, FetchableRecord {}

extension ImagesPropertiesTrackerResponse: Decodable {
  enum CodingKeys: CodingKey {
    case images, item
  }
}

public struct CopyingResponse {
  public let copying: CopyingInfo
  public let bookmark: BookmarkInfo
}

extension CopyingResponse: Sendable, Decodable, FetchableRecord {}

public struct BookmarkResponse {
  public let bookmark: BookmarkInfo
}

extension BookmarkResponse: Sendable, Decodable, FetchableRecord {}
