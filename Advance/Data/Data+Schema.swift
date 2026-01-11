//
//  Data+Schema.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/25.
//

import Foundation
import GRDB

typealias RowID = Int64

extension TableRecord {
  static var everyColumn: [any SQLSelectable] {
    [AllColumns(), Column.rowID]
  }
}

struct BookmarkRecord {
  var rowID: RowID?
  let data: Data?
  let options: URL.BookmarkCreationOptions?
}

extension BookmarkRecord: Equatable, FetchableRecord {}

extension BookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         data, options
  }

  enum Columns {
    static let data = Column(CodingKeys.data)
    static let options = Column(CodingKeys.options)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      rowID: try container.decodeIfPresent(RowID.self, forKey: .rowID),
      data: try container.decodeIfPresent(Data.self, forKey: .data),
      options: try container.decodeIfPresent(URL.BookmarkCreationOptions.self, forKey: .options),
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rowID, forKey: .rowID)
    try container.encode(data, forKey: .data)
    try container.encode(options, forKey: .options)
  }
}

extension BookmarkRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension BookmarkRecord: TableRecord {
  static let databaseTableName = "bookmarks"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }
}

struct FileBookmarkRecord {
  var rowID: RowID?
  let bookmark: RowID?
  let relative: RowID?

  init(rowID: RowID? = nil, bookmark: RowID?, relative: RowID?) {
    self.rowID = rowID
    self.bookmark = bookmark
    self.relative = relative
  }
}

extension FileBookmarkRecord: Equatable, FetchableRecord {}

extension FileBookmarkRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         bookmark, relative
  }

  enum Columns {
    static let bookmark = Column(CodingKeys.bookmark)
    static let relative = Column(CodingKeys.relative)
  }
}

extension FileBookmarkRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FileBookmarkRecord: TableRecord {
  static let databaseTableName = "file_bookmarks"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var bookmark: BelongsToAssociation<Self, BookmarkRecord> {
    Self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.bookmark]))
  }

  static var relative: BelongsToAssociation<Self, BookmarkRecord> {
    Self.belongsTo(BookmarkRecord.self, using: ForeignKey([Columns.relative]))
  }
}

struct ImagesItemRecord {
  var rowID: RowID?
  let fileBookmark: RowID?
  let position: String?
  let isBookmarked: Bool?
}

extension ImagesItemRecord: Equatable, FetchableRecord {}

extension ImagesItemRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         position,
         isBookmarked = "is_bookmarked",
         fileBookmark = "file_bookmark"
  }

  enum Columns {
    static let position = Column(CodingKeys.position)
    static let isBookmarked = Column(CodingKeys.isBookmarked)
    static let fileBookmark = Column(CodingKeys.fileBookmark)
  }
}

extension ImagesItemRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesItemRecord: TableRecord {
  static let databaseTableName = "image_collection_items"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var fileBookmark: BelongsToAssociation<Self, FileBookmarkRecord> {
    Self.belongsTo(FileBookmarkRecord.self, using: ForeignKey([Columns.fileBookmark]))
  }
}

struct ImagesRecord {
  var rowID: RowID?
  let id: UUID?
  let currentItem: RowID?
}

extension ImagesRecord: Equatable, FetchableRecord {}

extension ImagesRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         id,
         currentItem = "current_item"
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let currentItem = Column(CodingKeys.currentItem)
  }
}

extension ImagesRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ImagesRecord: TableRecord {
  static let databaseTableName = "image_collections"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var itemImages: HasManyAssociation<Self, ItemImagesRecord> {
    Self.hasMany(ItemImagesRecord.self, using: ForeignKey([ItemImagesRecord.Columns.images]))
  }

  static var items: HasManyThroughAssociation<Self, ImagesItemRecord> {
    Self.hasMany(ImagesItemRecord.self, through: itemImages, using: ItemImagesRecord.item)
  }

  static var currentItem: BelongsToAssociation<Self, ImagesItemRecord> {
    Self.belongsTo(ImagesItemRecord.self, using: ForeignKey([Columns.currentItem]))
  }
}

struct ItemImagesRecord {
  var rowID: RowID?
  let images: RowID?
  let item: RowID?

  init(rowID: RowID? = nil, images: RowID?, item: RowID?) {
    self.rowID = rowID
    self.images = images
    self.item = item
  }
}

extension ItemImagesRecord: Encodable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         images = "collection",
         item
  }

  enum Columns {
    static let images = Column(CodingKeys.images)
    static let item = Column(CodingKeys.item)
  }
}

extension ItemImagesRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension ItemImagesRecord: TableRecord {
  static let databaseTableName = "item_image_collections"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var item: BelongsToAssociation<Self, ImagesItemRecord> {
    Self.belongsTo(ImagesItemRecord.self, using: ForeignKey([Columns.item]))
  }
}

struct FolderPathComponentRecord {
  var rowID: RowID?
  let component: String?
  let position: Int?

  init(rowID: RowID? = nil, component: String?, position: Int?) {
    self.rowID = rowID
    self.component = component
    self.position = position
  }
}

extension FolderPathComponentRecord: Equatable {}

extension FolderPathComponentRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         component, position
  }

  enum Columns {
    static let component = Column(CodingKeys.component)
    static let position = Column(CodingKeys.position)
  }
}

extension FolderPathComponentRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FolderPathComponentRecord: TableRecord {
  static let databaseTableName = "folder_path_components"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }
}

struct FolderRecord {
  var rowID: RowID?
  let fileBookmark: RowID?

  init(rowID: RowID? = nil, fileBookmark: RowID?) {
    self.rowID = rowID
    self.fileBookmark = fileBookmark
  }
}

extension FolderRecord: Equatable {}

extension FolderRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         fileBookmark = "file_bookmark"
  }

  enum Columns {
    static let fileBookmark = Column(CodingKeys.fileBookmark)
  }
}

extension FolderRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension FolderRecord: TableRecord {
  static let databaseTableName = "folders"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var fileBookmark: BelongsToAssociation<Self, FileBookmarkRecord> {
    Self.belongsTo(FileBookmarkRecord.self, using: ForeignKey([Columns.fileBookmark]))
  }

  static var pathComponentFolders: HasManyAssociation<Self, PathComponentFolderRecord> {
    Self.hasMany(PathComponentFolderRecord.self, using: ForeignKey([PathComponentFolderRecord.Columns.folder]))
  }

  static var pathComponents: HasManyThroughAssociation<Self, FolderPathComponentRecord> {
    Self.hasMany(
      FolderPathComponentRecord.self,
      through: pathComponentFolders,
      using: PathComponentFolderRecord.pathComponent,
    )
  }
}

struct PathComponentFolderRecord {
  var rowID: RowID?
  let folder: RowID?
  let pathComponent: RowID?

  init(rowID: RowID? = nil, folder: RowID?, pathComponent: RowID?) {
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

  enum Columns {
    static let folder = Column(CodingKeys.folder)
    static let pathComponent = Column(CodingKeys.pathComponent)
  }
}

extension PathComponentFolderRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension PathComponentFolderRecord: TableRecord {
  static let databaseTableName = "path_component_folders"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var pathComponent: BelongsToAssociation<Self, FolderPathComponentRecord> {
    Self.belongsTo(FolderPathComponentRecord.self, using: ForeignKey([Columns.pathComponent]))
  }
}

struct SearchEngineRecord {
  var rowID: RowID?
  let name: String?
  let location: String?
  let position: String?
}

extension SearchEngineRecord: Equatable, FetchableRecord {}

extension SearchEngineRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         name, location, position
  }

  enum Columns {
    static let name = Column(CodingKeys.name)
    static let location = Column(CodingKeys.location)
    static let position = Column(CodingKeys.position)
  }
}

extension SearchEngineRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    rowID = inserted.rowID
  }
}

extension SearchEngineRecord: TableRecord {
  static let databaseTableName = "search_engines"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }
}

struct ConfigurationRecord {
  var rowID: RowID?
  var searchEngine: RowID?

  static let `default` = Self(rowID: 1, searchEngine: nil)
}

extension ConfigurationRecord: Codable {
  enum CodingKeys: String, CodingKey {
    case rowID = "rowid",
         searchEngine = "search_engine"
  }

  enum Columns {
    static let searchEngine = Column(CodingKeys.searchEngine)
  }
}

extension ConfigurationRecord: MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    self.rowID = inserted.rowID
  }
}

extension ConfigurationRecord: FetchableRecord {
  // While we could fetch and update else insert, there are default values which make sense to insert in an upsert,
  // meaning that we can save ourselves the headache of managing two separate codepaths.
  static func find(_ db: Database) throws -> Self {
    let record = Self.default
    let configuration = try self.fetchOne(db, key: record.rowID) ?? record

    return configuration
  }
}

extension ConfigurationRecord: TableRecord {
  static let databaseTableName = "configuration"
  static var databaseSelection: [any SQLSelectable] {
    Self.everyColumn
  }

  static var searchEngine: BelongsToAssociation<Self, SearchEngineRecord> {
    self.belongsTo(SearchEngineRecord.self, using: ForeignKey([Columns.searchEngine]))
  }
}
