//
//  SearchSettingsModelMoveSearchEngineInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/24/25.
//

import Foundation
import GRDB

struct SearchSettingsModelMoveSearchEngineInfo {
  let searchEngine: SearchEngineRecord
}

extension SearchSettingsModelMoveSearchEngineInfo: Decodable, FetchableRecord {}
