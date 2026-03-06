import JSONSchemaBuilder
import JSONSchema

/// Observability hooks for tool-call argument handling.
///
/// This mirrors the MCP-style messaging pattern while keeping OpenAI tool
/// execution behavior unchanged.
public protocol ToolCallMessaging: Sendable {
  /// Called when tool argument parsing fails.
  ///
  /// Use this callback for telemetry/reporting (for example OTel spans/events).
  func parsingFailed(_ context: ToolCallParsingFailedContext)

  /// Called when tool arguments parse successfully but fail schema validation.
  func validationFailed(_ context: ToolCallValidationFailedContext)

  /// Called when both parsing and validation fail for the same payload.
  func parsingAndValidationFailed(_ context: ToolCallParsingAndValidationFailedContext)

  /// Called when argument decoding fails before parsing/validation.
  func decodingFailed(_ context: ToolCallDecodingFailedContext)
}

public extension ToolCallMessaging {
  func validationFailed(_: ToolCallValidationFailedContext) {}
  func parsingAndValidationFailed(_: ToolCallParsingAndValidationFailedContext) {}
  func decodingFailed(_: ToolCallDecodingFailedContext) {}
}

/// Default no-op tool messaging.
public struct DefaultToolCallMessaging: ToolCallMessaging {
  public init() {}

  public func parsingFailed(_: ToolCallParsingFailedContext) {}
}

/// Context for failed tool argument parsing.
public struct ToolCallParsingFailedContext: Sendable {
  /// Name of the tool whose input failed parsing.
  public let toolName: String
  /// Raw JSON arguments string received from the model.
  public let arguments: String
  /// Human-readable parse issue descriptions.
  public let issues: [String]

  public init(toolName: String, arguments: String, issues: [ParseIssue]) {
    self.toolName = toolName
    self.arguments = arguments
    self.issues = issues.map(\.description)
  }
}

/// Context for failed tool argument validation.
public struct ToolCallValidationFailedContext: Sendable {
  /// Name of the tool whose input failed validation.
  public let toolName: String
  /// Raw JSON arguments string received from the model.
  public let arguments: String
  /// The detailed validation result.
  public let result: ValidationResult

  public init(toolName: String, arguments: String, result: ValidationResult) {
    self.toolName = toolName
    self.arguments = arguments
    self.result = result
  }
}

/// Context when both parsing and validation fail.
public struct ToolCallParsingAndValidationFailedContext: Sendable {
  /// Name of the tool whose input failed.
  public let toolName: String
  /// Raw JSON arguments string received from the model.
  public let arguments: String
  /// Human-readable parse issue descriptions.
  public let parseIssues: [String]
  /// The detailed validation result.
  public let validationResult: ValidationResult

  public init(
    toolName: String,
    arguments: String,
    parseIssues: [ParseIssue],
    validationResult: ValidationResult
  ) {
    self.toolName = toolName
    self.arguments = arguments
    self.parseIssues = parseIssues.map(\.description)
    self.validationResult = validationResult
  }
}

/// Context for JSON decoding errors before parsing/validation.
public struct ToolCallDecodingFailedContext: Sendable {
  /// Name of the tool whose input failed decoding.
  public let toolName: String
  /// Raw JSON arguments string received from the model.
  public let arguments: String
  /// Human-readable error representation.
  public let errorDescription: String

  public init(toolName: String, arguments: String, error: Error) {
    self.toolName = toolName
    self.arguments = arguments
    self.errorDescription = String(describing: error)
  }
}
