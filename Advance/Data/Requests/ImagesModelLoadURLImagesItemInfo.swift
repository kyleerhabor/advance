//
//  ImagesModelShowFinderImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/15/25.
//

import Foundation
import GRDB

struct ImagesModelLoadURLImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadURLImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadURLImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelLoadURLImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadURLImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadURLImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadURLImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadURLImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadURLImagesItemFileBookmarkInfo: FetchableRecord {}

struct ImagesModelLoadURLImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadURLImagesItemFileBookmarkInfo
}

extension ImagesModelLoadURLImagesItemInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadURLImagesItemInfo: FetchableRecord {}
