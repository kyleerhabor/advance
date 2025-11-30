//
//  FoldersSettingsModelOpenFinderFolderInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/30/25.
//

import AdvanceData
import GRDB

struct FoldersSettingsModelOpenFinderFolderFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension FoldersSettingsModelOpenFinderFolderFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct FoldersSettingsModelOpenFinderFolderFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: FoldersSettingsModelOpenFinderFolderFileBookmarkBookmarkInfo
}

extension FoldersSettingsModelOpenFinderFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension FoldersSettingsModelOpenFinderFolderFileBookmarkInfo: FetchableRecord {}

struct FoldersSettingsModelOpenFinderFolderInfo {
  let folder: FolderRecord
  let fileBookmark: FoldersSettingsModelOpenFinderFolderFileBookmarkInfo
}

extension FoldersSettingsModelOpenFinderFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark
  }
}

extension FoldersSettingsModelOpenFinderFolderInfo: FetchableRecord {}


