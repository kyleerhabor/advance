//
//  SearchSettingsModelLoadConfigurationInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/26/25.
//

import GRDB

struct SearchSettingsModelLoadConfigurationSearchEngineInfo {
  let searchEngine: SearchEngineRecord
}

extension SearchSettingsModelLoadConfigurationSearchEngineInfo: Decodable, FetchableRecord {}

struct SearchSettingsModelLoadConfigurationInfo {
  let configuration: ConfigurationRecord
  let searchEngine: SearchSettingsModelLoadConfigurationSearchEngineInfo?
}

extension SearchSettingsModelLoadConfigurationInfo: Decodable {
  enum CodingKeys: CodingKey {
    case configuration, searchEngine
  }
}

extension SearchSettingsModelLoadConfigurationInfo: FetchableRecord {}
