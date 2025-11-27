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
    .package(url: "https://github.com/groue/GRDB.swift", revision: "18497b68fdbb3a09528d260a0a0e1e7e61c8c53d"),
    .package(url: "https://github.com/leif-ibsen/BigInt.git", revision: "8c6f93aa37504b7b1ba3954335b5548a19fbbd82"),
  ],
  targets: [
    .target(
      name: "AdvanceCore",
      dependencies: [
        .product(name: "BigInt", package: "BigInt"),
      ],
    ),
    .target(
      name: "AdvanceData",
      dependencies: [
        .target(name: "AdvanceCore"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "BigInt", package: "BigInt"),
      ],
    ),
  ],
  swiftLanguageModes: [.v6],
)
