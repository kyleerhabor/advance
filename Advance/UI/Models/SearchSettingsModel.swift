//
//  SearchSettingsModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/31/24.
//

import Defaults
import Foundation
import IdentifiedCollections
import Observation

@Observable
class SearchSettingsEngineModel {
  static let keywordEnclosing: Character = "%"
  static let keyword = TokenFieldView.enclose("query", with: keywordEnclosing)

  let id: UUID
  var name: String
  var string: String

  init(id: UUID, name: String, string: String) {
    self.id = id
    self.name = name
    self.string = string
  }

  func url(text: String) -> URL? {
    let tokens = TokenFieldView
      .parse(token: string, enclosing: Self.keywordEnclosing)
      .map { token in
        guard token == Self.keyword else {
          return token
        }

        return text
      }

    let string = TokenFieldView.string(tokens: tokens)

    return URL(string: string)
  }
}

extension SearchSettingsEngineModel: Identifiable {}

struct SearchSettingsEngineFilter {
  var engines: IdentifiedArrayOf<SearchSettingsEngineModel>
  var names: Set<String>
}

@Observable
class SearchSettingsModel {
  var engines: IdentifiedArrayOf<SearchSettingsEngineModel>
  var engineID: SearchSettingsEngineModel.ID?

  var settingsEngines: IdentifiedArrayOf<SearchSettingsEngineModel>
  var engine: SearchSettingsEngineModel? {
    engineID.flatMap { settingsEngines[id: $0] }
  }

  init() {
    self.engines = []
    self.settingsEngines = []
  }

  private func submitEngines(_ engines: some Sequence<SearchSettingsEngineModel>) {
    Defaults[.searchEngines] = engines.map { engine in
      DefaultSearchEngine(id: engine.id, name: engine.name, string: engine.string)
    }
  }

  private func submitEngine(id: SearchSettingsEngineModel.ID?) {
    Defaults[.searchEngine] = id
  }

  func load(engines: [DefaultSearchEngine]) {
    let engines = engines.map { engine in
      SearchSettingsEngineModel(id: engine.id, name: engine.name, string: engine.string)
    }

    self.engines = IdentifiedArray(uniqueElements: engines)
    
    let results = engines.reduce(into: SearchSettingsEngineFilter(
      engines: IdentifiedArray(reservingCapacity: engines.count),
      names: Set(minimumCapacity: engines.count)
    )) { partialResult, engine in
      let name = engine.name
      
      if partialResult.names.contains(name) {
        return
      }
      
      partialResult.names.insert(name)

      if engine.url(text: "") == nil {
        return
      }

      partialResult.engines.append(engine)
    }

    self.settingsEngines = results.engines
  }
  
  @MainActor
  private func trackEngines() async {
    for await engines in Defaults.updates(.searchEngines) {
      load(engines: engines)
    }
  }

  @MainActor
  private func trackEngine() async {
    for await id in Defaults.updates(.searchEngine) {
      engineID = id
    }
  }

  @MainActor
  func load() async {
    async let engines: () = trackEngines()
    async let engine: () = trackEngine()

    _ = await [engines, engine]
  }

  func submitEngines() {
    submitEngines(engines)
  }

  func submitEngine() {
    submitEngine(id: engineID)
  }

  func submit(removalOf engine: SearchSettingsEngineModel) {
    let engines = engines.ids
      .subtracting([engine.id])
      .map { self.engines[id: $0]! }

    submitEngines(engines)
  }
}
