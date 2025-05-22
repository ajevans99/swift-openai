import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAPIRuntime

public protocol Tool {
  associatedtype Component: JSONSchemaComponent

  var name: String { get }
  var description: String? { get }
  var strict: Bool { get }

  @JSONSchemaBuilder
  var parameters: Component { get }

  func call(parameters: Component.Output) async throws -> String
}

public enum CallError: Error {
  case invalidParameters(issues: [ParseIssue])
}

extension Tool {
  func call(arguments: String) async throws -> String {
    let parameters = try parameters.parse(instance: arguments)
    switch parameters {
    case .valid(let parameters):
      return try await call(parameters: parameters)
    case .invalid(let issues):
      throw CallError.invalidParameters(issues: issues)
    }
  }
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

  public func toTool() -> Components.Schemas.Tool {
    .init(value1: toFunctionTool().toOpenAPI())
  }
}
