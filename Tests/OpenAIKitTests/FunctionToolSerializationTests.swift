import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import Testing

@Suite("FunctionTool Serialization")
struct FunctionToolSerializationTests {
  @Test("toOpenAPI includes description, parameters, and strict")
  func toOpenAPIIncludesSchemaFields() {
    let tool = FunctionTool(
      name: "list-editor-documents",
      description: "Lists editor documents for a comic",
      parameters: [
        "type": .init(stringLiteral: "object"),
        "additionalProperties": .init(booleanLiteral: false),
      ],
      strict: false
    )

    let openAPI = tool.toOpenAPI()

    #expect(openAPI.name == "list-editor-documents")
    #expect(openAPI.description == "Lists editor documents for a comic")
    #expect(openAPI.strict == false)
    #expect(openAPI.parameters != nil)
    let typeValue = openAPI.parameters?.value["type"] as? String
    #expect(typeValue == "object")
  }

  @Test("init from OpenAPI preserves schema fields")
  func initFromOpenAPIPreservesSchemaFields() {
    let source = FunctionTool(
      name: "update-editor-document",
      description: "Apply JSON patch",
      parameters: [
        "type": .init(stringLiteral: "object"),
        "additionalProperties": .init(booleanLiteral: false),
      ],
      strict: true
    ).toOpenAPI()

    let roundTripped = FunctionTool(source)

    #expect(roundTripped.name == "update-editor-document")
    #expect(roundTripped.description == "Apply JSON patch")
    #expect(roundTripped.strict == true)
    #expect(roundTripped.parameters.isEmpty == false)
    let typeValue = roundTripped.parameters["type"]?.value as? String
    #expect(typeValue == "object")
  }

  @Test("Toolable zero-arg object schema includes empty properties")
  func toolableZeroArgSchemaIncludesProperties() {
    let tool = NoArgumentsTool().toFunctionTool().toOpenAPI()
    let schema = tool.parameters?.value
    let properties = schema?["properties"] as? [String: Any]

    #expect(schema != nil)
    #expect(properties != nil)
    #expect(properties?.isEmpty == true)
  }

  @Test("Strict Toolable schemas normalize nullable unions and set additionalProperties false recursively")
  func strictToolableSchemaNormalizesNullableUnions() {
    let tool = StrictNestedArgumentsTool().toFunctionTool().toOpenAPI()
    let schema = tool.parameters?.value
    let rootAdditionalProperties = schema?["additionalProperties"] as? Bool
    let rootRequired = schema?["required"] as? [String]
    let groundings = ((schema?["properties"] as? [String: Any])?["groundings"] as? [String: Any])
    let groundingItems = groundings?["items"] as? [String: Any]
    let groundingAdditionalProperties = groundingItems?["additionalProperties"] as? Bool
    let groundingOneOf = groundings?["oneOf"] as? [Any]

    #expect(rootAdditionalProperties == false)
    #expect(rootRequired?.sorted() == ["groundings", "prompt"])
    #expect(groundingAdditionalProperties == false)
    #expect(groundingOneOf == nil)
  }
}

private struct NoArgumentsTool: Toolable {
  let name = "list-galleries"
  let description: String? = "List galleries."
  let strict = false

  var parameters: some JSONSchemaComponent<Void> {
    JSONObject {}
      .additionalProperties { false }
      .map { _ in () }
  }

  func call(parameters _: Void) async throws -> String {
    "[]"
  }
}

private struct StrictNestedArgumentsTool: Toolable {
  struct Parameters: Codable, Sendable {
    let prompt: String
    let groundings: [Grounding]?

    struct Grounding: Codable, Sendable {
      let type: String
      let id: String
    }
  }

  let name = "generate-grok-image"
  let description: String? = "Generate an image."
  let strict = true

  var parameters: some JSONSchemaComponent<Parameters> {
    JSONObject {
      JSONProperty(key: "prompt") {
        JSONString()
      }
      .required()

      JSONProperty(key: "groundings") {
        JSONArray {
          JSONObject {
            JSONProperty(key: "type") {
              JSONString()
            }
            .required()

            JSONProperty(key: "id") {
              JSONString()
            }
            .required()
          }
          .map { Parameters.Grounding(type: $0.0, id: $0.1) }
        }
      }
      .required()
    }
    .map { Parameters(prompt: $0.0, groundings: $0.1) }
  }

  func call(parameters _: Parameters) async throws -> String {
    "{}"
  }
}
