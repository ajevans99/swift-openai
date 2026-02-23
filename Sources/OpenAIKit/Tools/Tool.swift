import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAPIRuntime

public protocol Toolable: Sendable {
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
  case invalidParameterValidation(result: ValidationResult)
  case invalidParametersAndValidation(issues: [ParseIssue], result: ValidationResult)
  case invalidParameterDecoding(errorDescription: String)
}

extension Toolable {
  public func call(arguments: String) async throws -> String {
    try await call(arguments: arguments, messaging: DefaultToolCallMessaging())
  }

  public func call<M: ToolCallMessaging>(
    arguments: String,
    messaging: M
  ) async throws -> String {
    do {
      let parameters = try self.parameters.parseAndValidate(instance: arguments)
      return try await call(parameters: parameters)
    } catch ParseAndValidateIssue.parsingFailed(let issues) {
      messaging.parsingFailed(
        .init(toolName: name, arguments: arguments, issues: issues)
      )
      throw CallError.invalidParameters(issues: issues)
    } catch ParseAndValidateIssue.validationFailed(let result) {
      messaging.validationFailed(
        .init(toolName: name, arguments: arguments, result: result)
      )
      throw CallError.invalidParameterValidation(result: result)
    } catch ParseAndValidateIssue.parsingAndValidationFailed(let issues, let result) {
      messaging.parsingAndValidationFailed(
        .init(
          toolName: name,
          arguments: arguments,
          parseIssues: issues,
          validationResult: result
        )
      )
      throw CallError.invalidParametersAndValidation(issues: issues, result: result)
    } catch ParseAndValidateIssue.decodingFailed(let error) {
      messaging.decodingFailed(
        .init(toolName: name, arguments: arguments, error: error)
      )
      throw CallError.invalidParameterDecoding(errorDescription: String(describing: error))
    } catch {
      messaging.decodingFailed(
        .init(toolName: name, arguments: arguments, error: error)
      )
      throw CallError.invalidParameterDecoding(errorDescription: String(describing: error))
    }
  }
}

extension Toolable {
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

  public func toTool() -> OpenAICore.Tool {
    .function(toFunctionTool())
  }
}
