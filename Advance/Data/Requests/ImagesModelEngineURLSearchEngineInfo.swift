//
//  ImagesModelEngineURLSearchEngineInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/27/25.
//

import GRDB

struct ImagesModelEngineURLSearchEngineInfo {
  let searchEngine: SearchEngineRecord
}

extension ImagesModelEngineURLSearchEngineInfo: Decodable, FetchableRecord {}
