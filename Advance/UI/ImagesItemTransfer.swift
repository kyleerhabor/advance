//
//  ImagesItemTransfer.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/25/25.
//

import AdvanceCore
import CoreTransferable
import OSLog
import UniformTypeIdentifiers

struct ImagesItemTransfer {
  let source: URLSource
  let contentType: UTType
}

extension ImagesItemTransfer: Transferable {
  init(received: ReceivedTransferredFile, contentType: UTType) async throws {
    let source = URLSource(
      url: received.file,
      options: received.isOriginalFile
        ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        : [],
    )

    guard !received.isOriginalFile || source.url.relativeString.starts(with: URL.localTemporaryDirectory.relativeString) else {
      self.init(source: source, contentType: contentType)

      return
    }

    let directoryHint: URL.DirectoryHint = switch contentType {
      case .image: .notDirectory
      case .folder: .isDirectory
      default: unreachable()
    }

    let url = source.url.pathComponents.dropFirst().reduce(into: URL.imagesDirectory) { partialResult, component in
      partialResult.append(component: component, directoryHint: directoryHint)
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try source.accessingSecurityScopedResource {
      // In case the user drops a temporary file, we want to copy it so it doesn't disappear under their nose.
      try FileManager.default.copyItem(at: source.url, to: url)
    }

    self.init(source: URLSource(url: url, options: []), contentType: contentType)
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image, shouldAttemptToOpenInPlace: true) { received in
      try await Self(received: received, contentType: .image)
    }

    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      try await Self(received: received, contentType: .folder)
    }
  }
}
