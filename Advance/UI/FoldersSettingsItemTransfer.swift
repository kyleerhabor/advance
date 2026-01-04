//
//  FoldersSettingsItemTransfer.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/27/25.
//

import CoreTransferable
import UniformTypeIdentifiers

enum FoldersSettingsItemTransferableError: Error {
  case notOriginal
}

struct FoldersSettingsItemTransfer {
  let fileURL: URL
}

extension FoldersSettingsItemTransfer: Transferable {
  init(received: ReceivedTransferredFile) throws(FoldersSettingsItemTransferableError) {
    guard received.isOriginalFile else {
      throw FoldersSettingsItemTransferableError.notOriginal
    }

    self.init(fileURL: received.file)
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      try Self(received: received)
    }
  }
}
