//
//  ImagesModelLoadImageImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/15/25.
//

import GRDB

struct ImagesModelLoadImageImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadImageImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadImageImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelLoadImageImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadImageImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadImageImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadImageImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadImageImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadImageImagesItemFileBookmarkInfo: FetchableRecord {}

struct ImagesModelLoadImageImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadImageImagesItemFileBookmarkInfo
}

extension ImagesModelLoadImageImagesItemInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadImageImagesItemInfo: FetchableRecord {}
