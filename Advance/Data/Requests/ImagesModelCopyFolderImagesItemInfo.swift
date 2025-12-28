//
//  ImagesModelCopyFolderImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import GRDB

struct ImagesModelCopyFolderImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelCopyFolderImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelCopyFolderImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelCopyFolderImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct ImagesModelCopyFolderImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelCopyFolderImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelCopyFolderImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelCopyFolderImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

struct ImagesModelCopyFolderImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelCopyFolderImagesItemFileBookmarkInfo
}

extension ImagesModelCopyFolderImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelCopyFolderImagesItemInfo: FetchableRecord {}
