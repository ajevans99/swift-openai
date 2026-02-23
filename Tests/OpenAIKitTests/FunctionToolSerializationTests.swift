import OpenAICore
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
}
