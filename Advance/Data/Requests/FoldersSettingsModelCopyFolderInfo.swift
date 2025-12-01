//
//  FoldersSettingsModelCopyFolderInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import AdvanceData
import GRDB

struct FoldersSettingsModelCopyFolderFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension FoldersSettingsModelCopyFolderFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct FoldersSettingsModelCopyFolderFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: FoldersSettingsModelCopyFolderFileBookmarkBookmarkInfo
}

extension FoldersSettingsModelCopyFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension FoldersSettingsModelCopyFolderFileBookmarkInfo: FetchableRecord {}

struct FoldersSettingsModelCopyFolderInfo {
  let folder: FolderRecord
  let fileBookmark: FoldersSettingsModelCopyFolderFileBookmarkInfo
}

extension FoldersSettingsModelCopyFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark
  }
}

extension FoldersSettingsModelCopyFolderInfo: FetchableRecord {}
