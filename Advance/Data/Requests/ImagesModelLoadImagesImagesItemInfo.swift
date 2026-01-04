//
//  ImagesModelLoadImagesImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/15/25.
//

import GRDB

struct ImagesModelLoadImagesImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadImagesImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadImagesImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelLoadImagesImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadImagesImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadImagesImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadImagesImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadImagesImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadImagesImagesItemFileBookmarkInfo: FetchableRecord {}

struct ImagesModelLoadImagesImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadImagesImagesItemFileBookmarkInfo
}

extension ImagesModelLoadImagesImagesItemInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadImagesImagesItemInfo: FetchableRecord {}
