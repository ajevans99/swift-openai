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
      targets: ["OpenAI"]
    )
  ],
  dependencies: [
    // 📡 Swift OpenAPI Generator
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.7.2"),
    // 🔄 Swift OpenAPI Runtime
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.8.2"),
    // 📦 JSON Schema Builder for tools
    .package(url: "https://github.com/ajevans99/swift-json-schema.git", from: "0.5.0"),
  ],
  targets: [
    .target(
      name: "OpenAI",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
        "OpenAIModels",
      ]
    ),
    .testTarget(
      name: "OpenAITests",
      dependencies: ["OpenAI"]
    ),

    .target(
      name: "OpenAIModels",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ]
    ),
  ]
)
