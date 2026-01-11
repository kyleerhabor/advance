//
//  ImagesModelStoreMoveBeforeImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/11/26.
//

import GRDB

struct ImagesModelStoreMoveBeforeImagesItemInfo {
  let item: ImagesItemRecord
}

extension ImagesModelStoreMoveBeforeImagesItemInfo: Decodable, FetchableRecord {}
