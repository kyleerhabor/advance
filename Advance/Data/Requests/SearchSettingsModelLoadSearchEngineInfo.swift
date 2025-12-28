//
//  SearchSettingsModelLoadSearchEngineInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/23/25.
//

import Foundation
import GRDB

struct SearchSettingsModelLoadSearchEngineInfo {
  let searchEngine: SearchEngineRecord
}

extension SearchSettingsModelLoadSearchEngineInfo: Decodable, FetchableRecord {}
