//
//  SearchSettingsModelEngineURLSearchEngineInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/27/25.
//

import GRDB

struct SearchSettingsModelEngineURLSearchEngineInfo {
  let searchEngine: SearchEngineRecord
}

extension SearchSettingsModelEngineURLSearchEngineInfo: Decodable, FetchableRecord {}
