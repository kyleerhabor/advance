//
//  FoldersSettingsModelShowFinderFolderInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/30/25.
//

import AdvanceData
import GRDB

struct FoldersSettingsModelShowFinderFolderFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension FoldersSettingsModelShowFinderFolderFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct FoldersSettingsModelShowFinderFolderFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: FoldersSettingsModelShowFinderFolderFileBookmarkBookmarkInfo
}

extension FoldersSettingsModelShowFinderFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension FoldersSettingsModelShowFinderFolderFileBookmarkInfo: FetchableRecord {}

struct FoldersSettingsModelShowFinderFolderInfo {
  let folder: FolderRecord
  let fileBookmark: FoldersSettingsModelShowFinderFolderFileBookmarkInfo
}

extension FoldersSettingsModelShowFinderFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark
  }
}

extension FoldersSettingsModelShowFinderFolderInfo: FetchableRecord {}

