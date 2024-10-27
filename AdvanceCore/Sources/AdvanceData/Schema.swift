//
//  Schema.swift
//  
//
//  Created by Kyle Erhabor on 6/15/24.
//

import AdvanceCore
import CryptoKit
import Foundation
import GRDB

typealias RowID = Int64

func hash(data: Data) -> Data {
  Data(SHA256.hash(data: data))
}

extension TableRecord {
  static var everyColumn: [SQLSelectable] {
    [AllColumns(), Column.rowID]
  }
}

struct BookmarkRecord {
  var rowID: RowID?
  let data: Data
  let options: URL.BookmarkCreationOptions
  let hash: Data
  let relative: RowID?
}

extension BookmarkRecord {
  init(rowID: RowID? = nil, data: Data, options: URL.BookmarkCreationOptions, relative: RowID?) {
    self.init(
      rowID: rowID,
      data: data,
      options: options,
      hash: AdvanceData.hash(data: data),
      relative: relative
    )
  }

  init(rowID: RowID? = nil, bookmark: Bookmark, relative: RowID?) {
    self.init(
      rowID: rowID,
      data: bookmark.data,
      options: bookmark.options,
      relative: relative
    )
  }
}

extension BookmarkRecord: FetchableRecord {}

extension BookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         data, options, hash, relative
  }

  enum Columns {
    static let data = Column(CodingKeys.data)
    static let options = Column(CodingKeys.options)
    static let hash = Column(CodingKeys.hash)
    static let relative = Column(CodingKeys.relative)
  }
}

extension BookmarkRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension BookmarkRecord: TableRecord {
  static let databaseTableName = "bookmarks"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var relativeAssociation: BelongsToAssociation<Self, Self> {
    self.belongsTo(Self.self, using: ForeignKey([Columns.relative]))
  }

  var relativeRequest: QueryInterfaceRequest<Self> {
    self.request(for: Self.relativeAssociation)
  }
}

// MARK: - Images

struct ImageRecord {
  var rowID: RowID?
  let data: Data
  let hash: Data
}

extension ImageRecord {
  init(rowID: RowID? = nil, data: Data) {
    self.init(
      rowID: rowID,
      data: data,
      hash: AdvanceData.hash(data: data)
    )
  }
}

extension ImageRecord: FetchableRecord {}

extension ImageRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         data, hash
  }

  enum Columns {
    static let data = Column(CodingKeys.data)
    static let hash = Column(CodingKeys.hash)
  }
}

extension ImageRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImageRecord: TableRecord {
  static let databaseTableName = "images"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }
}

struct ImagesImageRecord {
  var rowID: RowID?
  let image: RowID
  let source: URL
}

extension ImagesImageRecord: FetchableRecord {}

extension ImagesImageRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         image,
         source
  }

  enum Columns {
    static let image = Column(CodingKeys.image)
    static let source = Column(CodingKeys.source)
  }
}

extension ImagesImageRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesImageRecord: TableRecord {
  static let databaseTableName = "image_collection_images"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var imageAssociation: BelongsToAssociation<Self, ImageRecord> {
    Self.belongsTo(ImageRecord.self, using: ForeignKey([Columns.image]))
  }

  var imageRequest: QueryInterfaceRequest<ImageRecord> {
    self.request(for: Self.imageAssociation)
  }
}

struct ImagesBookmarkRecord {
  var rowID: RowID?
  let bookmark: RowID
}

extension ImagesBookmarkRecord: FetchableRecord {}

extension ImagesBookmarkRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesBookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         bookmark
  }

  enum Columns {
    static let bookmark = Column(CodingKeys.bookmark)
  }
}

extension ImagesBookmarkRecord: TableRecord {
  static let databaseTableName = "image_collection_bookmarks"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var bookmarkAssociation: BelongsToAssociation<Self, BookmarkRecord> {
    self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.bookmark]))
  }

  var bookmarkRequest: QueryInterfaceRequest<BookmarkRecord> {
    self.request(for: Self.bookmarkAssociation)
  }
}

enum ImagesItemType: Int {
  case image, bookmark
}

extension ImagesItemType: Codable {}

struct ImagesItemRecord {
  var rowID: RowID?
  let id: UUID?
  let images: RowID?
  let priority: Int?
  let isBookmarked: Bool?
  let type: ImagesItemType?
  let image: RowID?
  let bookmark: RowID?

  init(
    rowID: RowID? = nil,
    id: UUID?,
    images: RowID?,
    priority: Int?,
    isBookmarked: Bool?,
    type: ImagesItemType?,
    image: RowID? = nil,
    bookmark: RowID? = nil
  ) {
    self.rowID = rowID
    self.id = id
    self.images = images
    self.priority = priority
    self.isBookmarked = isBookmarked
    self.type = type
    self.image = image
    self.bookmark = bookmark
  }
}

extension ImagesItemRecord: FetchableRecord {}

extension ImagesItemRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         id,
         images = "collection",
         priority,
         isBookmarked = "is_bookmarked",
         type, image, bookmark
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let images = Column(CodingKeys.images)
    static let priority = Column(CodingKeys.priority)
    static let isBookmarked = Column(CodingKeys.isBookmarked)
    static let type = Column(CodingKeys.type)
    static let image = Column(CodingKeys.image)
    static let bookmark = Column(CodingKeys.bookmark)
  }
}

extension ImagesItemRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesItemRecord: TableRecord {
  static let databaseTableName = "image_collection_items"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var imageAssociation: BelongsToAssociation<Self, ImagesImageRecord> {
    Self.belongsTo(ImagesImageRecord.self, using: ForeignKey([Columns.image]))
  }

  static var bookmarkAssociation: BelongsToAssociation<Self, ImagesBookmarkRecord> {
    Self.belongsTo(ImagesBookmarkRecord.self, using: ForeignKey([Columns.bookmark]))
  }

  var imageRequest: QueryInterfaceRequest<ImagesImageRecord> {
    self.request(for: Self.imageAssociation)
  }

  var bookmarkRequest: QueryInterfaceRequest<ImagesBookmarkRecord> {
    self.request(for: Self.bookmarkAssociation)
  }
}

struct ImagesRecord {
  var rowID: RowID?
  let id: UUID?
  let item: RowID?
}

extension ImagesRecord: FetchableRecord {}

extension ImagesRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         id,
         item = "current_item"
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let item = Column(CodingKeys.item)
  }
}

extension ImagesRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesRecord: TableRecord {
  static let databaseTableName = "image_collections"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var itemsAssociation: HasManyAssociation<Self, ImagesItemRecord> {
    Self.hasMany(ImagesItemRecord.self, using: ForeignKey([ImagesItemRecord.Columns.images]))
  }

  var itemsRequest: QueryInterfaceRequest<ImagesItemRecord> {
    self.request(for: Self.itemsAssociation)
  }

  static var itemAssociation: BelongsToAssociation<Self, ImagesItemRecord> {
    Self.belongsTo(ImagesItemRecord.self, using: ForeignKey([Columns.item]))
  }

  var itemRequest: QueryInterfaceRequest<ImagesItemRecord> {
    self.request(for: Self.itemAssociation)
  }
}

// MARK: - Copying

struct CopyingRecord {
  var rowID: RowID?
  let id: UUID?
  let bookmark: RowID?
  let url: URL?
}

extension CopyingRecord: Encodable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         id,
         bookmark,
         url
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let bookmark = Column(CodingKeys.bookmark)
    static let url = Column(CodingKeys.url)
  }
}

extension CopyingRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension CopyingRecord: TableRecord {
  static let databaseTableName = "copyings"

  static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  static var bookmarkAssociation: BelongsToAssociation<Self, BookmarkRecord> {
    Self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.bookmark]))
  }

  var bookmarkRequest: QueryInterfaceRequest<BookmarkRecord> {
    self.request(for: Self.bookmarkAssociation)
  }
}
