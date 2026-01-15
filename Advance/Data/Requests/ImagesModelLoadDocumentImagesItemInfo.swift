//
//  ImagesModelLoadDocumentImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/15/25.
//

import Foundation
import GRDB

struct ImagesModelLoadDocumentImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadDocumentImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadDocumentImagesItemFileBookmarkRelativeInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadDocumentImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct ImagesModelLoadDocumentImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadDocumentImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadDocumentImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadDocumentImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadDocumentImagesItemFileBookmarkInfo: FetchableRecord {}

struct ImagesModelLoadDocumentImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadDocumentImagesItemFileBookmarkInfo
}

extension ImagesModelLoadDocumentImagesItemInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadDocumentImagesItemInfo: FetchableRecord {}
