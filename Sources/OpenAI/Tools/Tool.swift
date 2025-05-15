import JSONSchemaBuilder
import OpenAIModels
import OpenAPIRuntime

public protocol Tool {
  associatedtype Parameters: JSONSchemaComponent

  var name: String { get }
  var description: String? { get }
  var strict: Bool { get }

  @JSONSchemaBuilder
  var parameters: Parameters { get }
}

extension Tool {
  public func toFunctionTool() -> FunctionTool {
    guard case .object(let parameters) = parameters.schemaValue else {
      fatalError("Boolean schemas are not supported at root level for tools")
    }

    return FunctionTool(
      name: name,
      description: description,
      parameters: parameters.mapValues {
        OpenAPIValueContainer(jsonValue: $0)
      },
      strict: strict
    )
  }
}
