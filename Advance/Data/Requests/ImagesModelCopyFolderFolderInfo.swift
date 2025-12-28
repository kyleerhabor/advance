//
//  ImagesModelCopyFolderFolderInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/1/25.
//

import GRDB

struct ImagesModelCopyFolderFolderFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelCopyFolderFolderFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelCopyFolderFolderFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelCopyFolderFolderFileBookmarkBookmarkInfo
}

extension ImagesModelCopyFolderFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension ImagesModelCopyFolderFolderFileBookmarkInfo: FetchableRecord {}

struct ImagesModelCopyFolderFolderInfo {
  let folder: FolderRecord
  let fileBookmark: ImagesModelCopyFolderFolderFileBookmarkInfo
}

extension ImagesModelCopyFolderFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark
  }
}

extension ImagesModelCopyFolderFolderInfo: FetchableRecord {}
