// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "swift-openai",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "OpenAI",
      targets: ["OpenAIKit", "OpenAICore", "OpenAIFoundation"]
    ),
    .library(
      name: "OpenAIKit",
      targets: ["OpenAIKit"]
    ),
    .library(
      name: "OpenAICore",
      targets: ["OpenAICore"]
    ),
    .library(
      name: "OpenAIFoundation",
      targets: ["OpenAIFoundation"]
    ),
  ],
  dependencies: [
    // 📡 Swift OpenAPI Generator
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.7.2"),
    // 🔄 Swift OpenAPI Runtime
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.8.2"),
    // 📦 JSON Schema Builder for tools
    .package(url: "https://github.com/ajevans99/swift-json-schema.git", .upToNextMinor(from: "0.5.0")),
    // 🪵 Logging
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    // 🧾 Better diffs in tests
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
  ],
  targets: [
    .target(
      name: "OpenAIKit",
      dependencies: [
        "OpenAICore",
        "OpenAIFoundation",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
      ]
    ),
    .testTarget(
      name: "OpenAIKitTests",
      dependencies: [
        "OpenAIKit",
        "OpenAICore",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      resources: [
        .copy("Fixtures")
      ]
    ),

    .target(
      name: "OpenAICore",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        "OpenAIFoundation",
        .product(name: "Logging", package: "swift-log"),
      ]
    ),

    .target(
      name: "OpenAIFoundation",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ],
      exclude: [
        "openapi-generator-config.yaml",
        "openapi.yaml",
        "openapi.commit",
      ]
    ),
  ]
)
