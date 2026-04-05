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
    guard case .object(let rawParameters) = parameters.schemaValue else {
      fatalError("Boolean schemas are not supported at root level for tools")
    }

    let parameters = Self.normalizeToolSchemaObject(rawParameters, strict: strict)

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

  private static func normalizeToolSchemaObject(
    _ schemaObject: [KeywordIdentifier: JSONValue],
    strict: Bool
  ) -> [KeywordIdentifier: JSONValue] {
    var normalized = schemaObject.mapValues {
      normalizeToolSchemaValue($0, strict: strict)
    }

    normalized = collapseNullableCompositions(in: normalized)

    if normalized["type"] == .string("object"), normalized["properties"] == nil {
      normalized["properties"] = .object([:])
    }

    if strict, normalized["type"] == .string("object"), normalized["additionalProperties"] == nil {
      normalized["additionalProperties"] = .boolean(false)
    }

    if strict,
      normalized["type"] == .string("object"),
      let properties = normalized["properties"]?.object
    {
      let requiredKeys =
        (normalized["required"]?.array?.compactMap(\.string) ?? []) + properties.keys
      let deduplicated = Array(Set(requiredKeys)).sorted().map(JSONValue.string)
      normalized["required"] = .array(deduplicated)
    }

    return normalized
  }

  private static func normalizeToolSchemaValue(
    _ value: JSONValue,
    strict: Bool
  ) -> JSONValue {
    switch value {
    case .object(let object):
      return .object(normalizeToolSchemaObject(object, strict: strict))
    case .array(let array):
      return .array(array.map { normalizeToolSchemaValue($0, strict: strict) })
    default:
      return value
    }
  }

  private static func collapseNullableCompositions(
    in schemaObject: [KeywordIdentifier: JSONValue]
  ) -> [KeywordIdentifier: JSONValue] {
    for keyword in ["oneOf", "anyOf"] {
      guard let composition = schemaObject[keyword]?.array else { continue }

      let nonNullBranches = composition.filter { !isNullSchema($0) }
      guard nonNullBranches.count == 1, case .object(let branchObject) = nonNullBranches[0] else {
        continue
      }

      var collapsed = schemaObject
      collapsed.removeValue(forKey: keyword)
      var nullableBranch = branchObject
      nullableBranch["type"] = appendNullType(to: branchObject["type"])
      collapsed.merge(nullableBranch) { current, _ in current }
      return collapsed
    }

    return schemaObject
  }

  private static func isNullSchema(_ value: JSONValue) -> Bool {
    guard case .object(let object) = value else { return false }
    return object["type"] == .string("null")
  }

  private static func appendNullType(to value: JSONValue?) -> JSONValue? {
    guard let value else { return nil }

    switch value {
    case .string(let string):
      return .array([.string(string), .string("null")])
    case .array(let values):
      if values.contains(.string("null")) {
        return .array(values)
      }
      return .array(values + [.string("null")])
    default:
      return value
    }
  }
}
