// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AdvanceCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AdvanceCore", targets: ["AdvanceCore"]),
    .library(name: "AdvanceData", targets: ["AdvanceData"])
  ],
  dependencies: [
    // v6.27.0
    .package(url: "https://github.com/groue/GRDB.swift", revision: "dd6b98ce04eda39aa22f066cd421c24d7236ea8a"),
  ],
  targets: [
    .target(name: "AdvanceCore"),
    .target(
      name: "AdvanceData",
      dependencies: [
        .target(name: "AdvanceCore"),
        .product(name: "GRDB", package: "GRDB.swift")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
