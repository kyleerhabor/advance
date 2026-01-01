//
//  ImagesModelLoadImagesInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/31/25.
//

import Foundation
import GRDB

struct ImagesModelLoadImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadImagesItemFileBookmarkBookmarkInfo: Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelLoadImagesItemFileBookmarkRelativeInfo: Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadImagesItemFileBookmarkInfo: Equatable, FetchableRecord {}

struct ImagesModelLoadImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadImagesItemFileBookmarkInfo
}

extension ImagesModelLoadImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadImagesItemInfo: Equatable, FetchableRecord {}

struct ImagesModelLoadImagesCurrentItemInfo {
  let item: ImagesItemRecord
}

extension ImagesModelLoadImagesCurrentItemInfo: Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesInfo {
  let images: ImagesRecord
  let currentItem: ImagesModelLoadImagesCurrentItemInfo?
  let items: [ImagesModelLoadImagesItemInfo]
}

extension ImagesModelLoadImagesInfo: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.images == rhs.images && lhs.items == rhs.items
  }
}

extension ImagesModelLoadImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, currentItem, items
  }
}

extension ImagesModelLoadImagesInfo: FetchableRecord {}
