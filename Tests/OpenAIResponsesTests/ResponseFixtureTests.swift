import Foundation
import JSONSchema
import Testing

struct ResponseFixtureTests {
  enum Failure: Error {
    case invalidSpecificationRoot
  }

  @Test("Recording fixture satisfies the original pinned Response schema")
  func fixtureMatchesPinnedResponseSchema() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let specification = try JSONValue.parse(
      String(
        contentsOf: root.appendingPathComponent("Generation/OpenAIResponses/openapi.json"),
        encoding: .utf8
      )
    )
    guard case .object(let document) = specification else {
      throw Failure.invalidSpecificationRoot
    }
    let components = try #require(document["components"])
    let schema = try Schema(
      rawSchema: .object([
        "$ref": .string("#/components/schemas/Response"),
        "components": components,
      ]),
      context: .init(dialect: .draft2020_12)
    )
    let fixture = try #require(
      Bundle.module.url(forResource: "response", withExtension: "json", subdirectory: "Fixtures")
    )
    let value = try JSONValue.parse(String(contentsOf: fixture, encoding: .utf8))
    let result = schema.validate(value, at: .init())
    #expect(result.isValid, "\(result)")
  }
}
