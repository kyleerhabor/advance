// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AdvanceCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AdvanceCore", targets: ["AdvanceCore"]),
    .library(name: "AdvanceData", targets: ["AdvanceData"]),
  ],
  dependencies: [
    // v6.27.0
    .package(url: "https://github.com/groue/GRDB.swift", revision: "c5d02eac3241dd980fa42e5644afd2e7e3f63401"),
  ],
  targets: [
    .target(name: "AdvanceCore"),
    .target(
      name: "AdvanceData",
      dependencies: [
        .target(name: "AdvanceCore"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
    ),
  ],
  swiftLanguageModes: [.v6],
)
