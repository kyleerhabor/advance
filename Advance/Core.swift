//
//  Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/31/25.
//

import Foundation

// MARK: - Swift

// https://www.swiftbysundell.com/articles/the-power-of-key-paths-in-swift/
func setter<Object, Value>(
  on keyPath: WritableKeyPath<Object, Value>,
  value: Value,
) -> (inout Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}

func setter<Object: AnyObject, Value>(
  on keyPath: ReferenceWritableKeyPath<Object, Value>,
  value: Value,
) -> (Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}

extension OperationQueue {
  static let translate: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount

    return queue
  }()
}

// In some settings, calling a synchronous function from an asynchronous one can block the underlying cooperative thread,
// deadlocking the system when all cooperative threads are blocked (e.g., calling URL/bookmarkData(options:includingResourceValuesForKeys:relativeTo:)
// from a task group). I presume this is caused by a function:
//
//   1. Not being preconcurrency
//   2. Being I/O bound
//   3. Blocking a cooperative thread
//
// The solution, then, is to not block cooperative threads. We use dispatch queues here, but it results in thread
// explosion. To resolve this, we need a scheduler that limits the number of threads, such as an operation queue.
//
// See https://forums.swift.org/t/cooperative-pool-deadlock-when-calling-into-an-opaque-subsystem/70685
func withTranslatingCheckedContinuation<T>(
  on queue: DispatchQueue = .global(),
  _ body: @escaping @Sendable () throws -> T,
) async throws -> T {
  try await withCheckedThrowingContinuation { continuation in
//    OperationQueue.translate.addOperation {
//      do {
//        continuation.resume(returning: try body())
//      } catch {
//        continuation.resume(throwing: error)
//      }
//    }
    queue.async {
      do {
        continuation.resume(returning: try body())
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

// MARK: - Foundation

extension URL {
  #if DEBUG
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "DebugData",
    directoryHint: .isDirectory,
  )

  #else
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "Data",
    directoryHint: .isDirectory,
  )

  #endif
}
