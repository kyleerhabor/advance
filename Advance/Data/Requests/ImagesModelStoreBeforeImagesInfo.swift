//
//  ImagesModelStoreBeforeImagesInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/10/26.
//

import GRDB

struct ImagesModelStoreBeforeImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
}

extension ImagesModelStoreBeforeImagesItemFileBookmarkInfo: Decodable, FetchableRecord {}

struct ImagesModelStoreBeforeImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelStoreBeforeImagesItemFileBookmarkInfo
}

extension ImagesModelStoreBeforeImagesItemInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelStoreBeforeImagesItemInfo: FetchableRecord {}

struct ImagesModelStoreBeforeImagesInfo {
  let images: ImagesRecord
  let items: [ImagesModelStoreBeforeImagesItemInfo]
}

extension ImagesModelStoreBeforeImagesInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case images, items
  }
}

extension ImagesModelStoreBeforeImagesInfo: FetchableRecord {}
