//
//  Schema.swift
//  
//
//  Created by Kyle Erhabor on 6/15/24.
//

import AdvanceCore
@preconcurrency import BigInt
import CryptoKit
import Foundation
import GRDB

public typealias RowID = Int64

func hash(data: Data) -> Data {
  Data(SHA256.hash(data: data))
}

extension TableRecord {
  static var everyColumn: [SQLSelectable] {
    [AllColumns(), Column.rowID]
  }
}

public struct BookmarkRecord {
  public var rowID: RowID?
  public let data: Data?
  public let options: URL.BookmarkCreationOptions?
  public let hash: Data?

  public init(rowID: RowID? = nil, data: Data?, options: URL.BookmarkCreationOptions?, hash: Data?) {
    self.rowID = rowID
    self.data = data
    self.options = options
    self.hash = hash
  }
}

extension BookmarkRecord: Sendable, Equatable, FetchableRecord {}

extension BookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         data, options, hash
  }

  public enum Columns {
    public static let data = Column(CodingKeys.data)
    public static let options = Column(CodingKeys.options)
    public static let hash = Column(CodingKeys.hash)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
      rowID: try container.decodeIfPresent(RowID.self, forKey: .rowID),
      data: try container.decodeIfPresent(Data.self, forKey: .data),
      options: try container.decodeIfPresent(URL.BookmarkCreationOptions.self, forKey: .options),
      hash: try container.decodeIfPresent(Data.self, forKey: .hash),
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rowID, forKey: .rowID)
    try container.encode(data, forKey: .data)
    try container.encode(options, forKey: .options)
    try container.encode(hash, forKey: .hash)
  }
}

extension BookmarkRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension BookmarkRecord: TableRecord {
  public static let databaseTableName = "bookmarks"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }
}

public struct FileBookmarkRecord {
  public var rowID: RowID?
  public let bookmark: RowID?
  public let relative: RowID?

  public init(rowID: RowID? = nil, bookmark: RowID?, relative: RowID?) {
    self.rowID = rowID
    self.bookmark = bookmark
    self.relative = relative
  }
}

extension FileBookmarkRecord: Sendable, Equatable, FetchableRecord {}

extension FileBookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         bookmark, relative
  }

  public enum Columns {
    public static let bookmark = Column(CodingKeys.bookmark)
    public static let relative = Column(CodingKeys.relative)
  }
}

extension FileBookmarkRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FileBookmarkRecord: TableRecord {
  public static let databaseTableName = "file_bookmarks"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  public static var bookmark: BelongsToAssociation<Self, BookmarkRecord> {
    Self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.bookmark]))
  }

  public static var relative: BelongsToAssociation<Self, BookmarkRecord> {
    Self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.relative]))
  }
}

public struct ImagesItemRecord {
  public var rowID: RowID?
  public let position: BigFraction?
  // TODO: Replace with above.
  public let priority: Int?
  public let isBookmarked: Bool?
  public let fileBookmark: RowID?

  public init(rowID: RowID? = nil, position: BigFraction?, priority: Int?, isBookmarked: Bool?, fileBookmark: RowID?) {
    self.rowID = rowID
    self.position = position
    self.priority = priority
    self.isBookmarked = isBookmarked
    self.fileBookmark = fileBookmark
  }
}

extension ImagesItemRecord: Sendable, Equatable, FetchableRecord {}

extension ImagesItemRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         position, priority,
         isBookmarked = "is_bookmarked",
         fileBookmark = "file_bookmark"
  }

  public enum Columns {
    public static let position = Column(CodingKeys.position)
    public static let priority = Column(CodingKeys.priority)
    public static let isBookmarked = Column(CodingKeys.isBookmarked)
    public static let fileBookmark = Column(CodingKeys.fileBookmark)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.rowID = try container.decodeIfPresent(RowID.self, forKey: .rowID)
    self.position = try container
      .decodeIfPresent(String.self, forKey: .position)
      .flatMap(BigFraction.init(_:))

    self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
    self.isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked)
    self.fileBookmark = try container.decodeIfPresent(RowID.self, forKey: .fileBookmark)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rowID, forKey: .rowID)
    // We should probably compute the precision, but I'm not aware of a method that doesn't involve loops.
    try container.encode(position.map { $0.asDecimalString(precision: 10) }, forKey: .position)
    try container.encode(priority, forKey: .priority)
    try container.encode(isBookmarked, forKey: .isBookmarked)
    try container.encode(fileBookmark, forKey: .fileBookmark)
  }
}

extension ImagesItemRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesItemRecord: TableRecord {
  public static let databaseTableName = "image_collection_items"
  public static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  public static var fileBookmark: BelongsToAssociation<Self, FileBookmarkRecord> {
    Self.belongsTo(FileBookmarkRecord.self, using: ForeignKey([Columns.fileBookmark]))
  }
}

public struct ImagesRecord {
  public var rowID: RowID?
  public let id: UUID?
  public let currentItem: RowID?

  public init(rowID: RowID? = nil, id: UUID?, currentItem: RowID?) {
    self.rowID = rowID
    self.id = id
    self.currentItem = currentItem
  }
}

extension ImagesRecord: Sendable, Equatable, FetchableRecord {}

extension ImagesRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         id,
         currentItem = "current_item"
  }

  public enum Columns {
    public static let id = Column(CodingKeys.id)
    public static let currentItem = Column(CodingKeys.currentItem)
  }
}

extension ImagesRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesRecord: TableRecord {
  public static let databaseTableName = "image_collections"
  public static var databaseSelection: [SQLSelectable] {
    Self.everyColumn
  }

  public static var itemImages: HasManyAssociation<Self, ItemImagesRecord> {
    Self.hasMany(ItemImagesRecord.self, using: ForeignKey([ItemImagesRecord.Columns.images]))
  }

  public static var items: HasManyThroughAssociation<Self, ImagesItemRecord> {
    Self.hasMany(ImagesItemRecord.self, through: itemImages, using: ItemImagesRecord.item)
  }

  static var currentItem: BelongsToAssociation<Self, ImagesItemRecord> {
    Self.belongsTo(ImagesItemRecord.self, using: ForeignKey([Columns.currentItem]))
  }
}

public struct ItemImagesRecord {
  public var rowID: RowID?
  public let images: RowID?
  public let item: RowID?

  public init(rowID: RowID? = nil, images: RowID?, item: RowID?) {
    self.rowID = rowID
    self.images = images
    self.item = item
  }
}

extension ItemImagesRecord: Encodable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         images = "image_collection",
         item
  }

  public enum Columns {
    public static let images = Column(CodingKeys.images)
    public static let item = Column(CodingKeys.item)
  }
}

extension ItemImagesRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ItemImagesRecord: TableRecord {
  public static let databaseTableName = "item_image_collections"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  public static var item: BelongsToAssociation<Self, ImagesItemRecord> {
    Self.belongsTo(ImagesItemRecord.self, using: ForeignKey([Columns.item]))
  }
}

public struct FolderRecord {
  public var rowID: RowID?
  public let fileBookmark: RowID?
  public let url: URL?
}

extension FolderRecord: Sendable, Equatable {}

extension FolderRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         fileBookmark = "file_bookmark",
         url
  }

  public enum Columns {
    static let fileBookmark = Column(CodingKeys.fileBookmark)
    static let url = Column(CodingKeys.url)
  }
}

extension FolderRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FolderRecord: TableRecord {
  public static let databaseTableName = "folders"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var fileBookmark: BelongsToAssociation<Self, FileBookmarkRecord> {
    Self.belongsTo(FileBookmarkRecord.self, using: ForeignKey([Columns.fileBookmark]))
  }
}
