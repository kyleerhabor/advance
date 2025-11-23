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
    .package(url: "https://github.com/mgriebling/BigDecimal.git", revision: "4414e0e82bb859cf5a2883f9401e7d7cb030f5b1"),
  ],
  targets: [
    .target(
      name: "AdvanceCore",
      dependencies: [
        .product(name: "BigDecimal", package: "BigDecimal"),
      ],
    ),
    .target(
      name: "AdvanceData",
      dependencies: [
        .target(name: "AdvanceCore"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "BigDecimal", package: "BigDecimal"),
      ],
    ),
  ],
  swiftLanguageModes: [.v6],
)
