//
//  Schema.swift
//  
//
//  Created by Kyle Erhabor on 6/15/24.
//

import AdvanceCore
@preconcurrency import BigInt
import Foundation
import GRDB

public typealias RowID = Int64

extension TableRecord {
  static var everyColumn: [SQLSelectable] {
    [AllColumns(), Column.rowID]
  }
}

public struct BookmarkRecord {
  public var rowID: RowID?
  public let data: Data?
  public let options: URL.BookmarkCreationOptions?

  public init(rowID: RowID? = nil, data: Data?, options: URL.BookmarkCreationOptions?) {
    self.rowID = rowID
    self.data = data
    self.options = options
  }
}

extension BookmarkRecord: Sendable, Equatable, FetchableRecord {}

extension BookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         data, options
  }

  public enum Columns {
    public static let data = Column(CodingKeys.data)
    public static let options = Column(CodingKeys.options)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      rowID: try container.decodeIfPresent(RowID.self, forKey: .rowID),
      data: try container.decodeIfPresent(Data.self, forKey: .data),
      options: try container.decodeIfPresent(URL.BookmarkCreationOptions.self, forKey: .options),
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rowID, forKey: .rowID)
    try container.encode(data, forKey: .data)
    try container.encode(options, forKey: .options)
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
  public let isBookmarked: Bool?
  public let fileBookmark: RowID?

  public init(rowID: RowID? = nil, position: BigFraction?, isBookmarked: Bool?, fileBookmark: RowID?) {
    self.rowID = rowID
    self.position = position
    self.isBookmarked = isBookmarked
    self.fileBookmark = fileBookmark
  }
}

extension ImagesItemRecord: Sendable, Equatable, FetchableRecord {}

extension ImagesItemRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         position,
         isBookmarked = "is_bookmarked",
         fileBookmark = "file_bookmark"
  }

  public enum Columns {
    public static let position = Column(CodingKeys.position)
    public static let isBookmarked = Column(CodingKeys.isBookmarked)
    public static let fileBookmark = Column(CodingKeys.fileBookmark)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.rowID = try container.decodeIfPresent(RowID.self, forKey: .rowID)
    self.position = try container
      .decodeIfPresent(String.self, forKey: .position)
      .flatMap(BigFraction.init(_:))

    self.isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked)
    self.fileBookmark = try container.decodeIfPresent(RowID.self, forKey: .fileBookmark)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rowID, forKey: .rowID)
    // We should probably compute the precision, but I'm not aware of a method that doesn't involve loops.
    try container.encode(position.map { $0.asDecimalString(precision: 10) }, forKey: .position)
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

public struct FolderPathComponentRecord {
  public var rowID: RowID?
  public let component: String?
  public let position: Int?

  public init(rowID: RowID? = nil, component: String?, position: Int?) {
    self.rowID = rowID
    self.component = component
    self.position = position
  }
}

extension FolderPathComponentRecord: Sendable, Equatable {}

extension FolderPathComponentRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         component, position
  }

  public enum Columns {
    public static let component = Column(CodingKeys.component)
    public static let position = Column(CodingKeys.position)
  }
}

extension FolderPathComponentRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FolderPathComponentRecord: TableRecord {
  public static let databaseTableName = "folder_path_components"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }
}

public struct FolderRecord {
  public var rowID: RowID?
  public let fileBookmark: RowID?

  public init(rowID: RowID? = nil, fileBookmark: RowID?) {
    self.rowID = rowID
    self.fileBookmark = fileBookmark
  }
}

extension FolderRecord: Sendable, Equatable {}

extension FolderRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         fileBookmark = "file_bookmark"
  }

  public enum Columns {
    static let fileBookmark = Column(CodingKeys.fileBookmark)
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

  public static var fileBookmark: BelongsToAssociation<Self, FileBookmarkRecord> {
    Self.belongsTo(FileBookmarkRecord.self, using: ForeignKey([Columns.fileBookmark]))
  }

  static var pathComponentFolders: HasManyAssociation<Self, PathComponentFolderRecord> {
    Self.hasMany(PathComponentFolderRecord.self, using: ForeignKey([PathComponentFolderRecord.Columns.folder]))
  }

  public static var pathComponents: HasManyThroughAssociation<Self, FolderPathComponentRecord> {
    Self.hasMany(
      FolderPathComponentRecord.self,
      through: pathComponentFolders,
      using: PathComponentFolderRecord.pathComponent,
    )
  }
}

public struct PathComponentFolderRecord {
  public var rowID: RowID?
  public let folder: RowID?
  public let pathComponent: RowID?

  public init(rowID: RowID? = nil, folder: RowID?, pathComponent: RowID?) {
    self.rowID = rowID
    self.folder = folder
    self.pathComponent = pathComponent
  }
}

extension PathComponentFolderRecord: Encodable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         folder,
         pathComponent = "path_component"
  }

  public enum Columns {
    static let folder = Column(CodingKeys.folder)
    static let pathComponent = Column(CodingKeys.pathComponent)
  }
}

extension PathComponentFolderRecord: MutablePersistableRecord {
  public mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension PathComponentFolderRecord: TableRecord {
  public static let databaseTableName = "path_component_folders"
  public static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var pathComponent: BelongsToAssociation<Self, FolderPathComponentRecord> {
    Self.belongsTo(FolderPathComponentRecord.self, using: ForeignKey([Columns.pathComponent]))
  }
}
