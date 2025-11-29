//
//  FoldersSettingsModelCopyImagesItemInfo.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import AdvanceData
import GRDB

struct FoldersSettingsModelCopyImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension FoldersSettingsModelCopyImagesItemFileBookmarkBookmarkInfo: Decodable, FetchableRecord {}

struct FoldersSettingsModelCopyImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension FoldersSettingsModelCopyImagesItemFileBookmarkRelativeInfo: Decodable, FetchableRecord {}

struct FoldersSettingsModelCopyImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: FoldersSettingsModelCopyImagesItemFileBookmarkBookmarkInfo
  let relative: FoldersSettingsModelCopyImagesItemFileBookmarkRelativeInfo?
}

extension FoldersSettingsModelCopyImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

struct FoldersSettingsModelCopyImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: FoldersSettingsModelCopyImagesItemFileBookmarkInfo
}

extension FoldersSettingsModelCopyImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension FoldersSettingsModelCopyImagesItemInfo: FetchableRecord {}
