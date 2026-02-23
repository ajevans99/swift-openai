import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAIKit
import Testing

@Suite("Tool Call Messaging")
struct ToolCallMessagingTests {
  @Test("Parsing and validation failure calls combined hook with tool context")
  func parsingAndValidationFailureHook() async throws {
    let capture = ToolCallCapture()
    let messaging = RecordingToolCallMessaging(capture: capture)
    let tool = EchoLocationTool()
    let invalidArguments = #"{"city":"San Francisco"}"#

    do {
      _ = try await tool.call(arguments: invalidArguments, messaging: messaging)
      Issue.record("Expected parsing and validation to fail")
    } catch CallError.invalidParametersAndValidation(let issues, let result) {
      #expect(!issues.isEmpty)
      #expect(!result.isValid)
    } catch {
      Issue.record("Expected CallError.invalidParametersAndValidation, got \(error)")
    }

    let failures = capture.parsingAndValidationSnapshot()
    #expect(failures.count == 1)
    #expect(failures.first?.toolName == "echo_location")
    #expect(failures.first?.arguments == invalidArguments)
    #expect(!(failures.first?.parseIssues.isEmpty ?? true))
    #expect(!(failures.first?.validationResult.isValid ?? true))
  }

  @Test("Successful parse does not call messaging hook")
  func successfulParseSkipsHook() async throws {
    let capture = ToolCallCapture()
    let messaging = RecordingToolCallMessaging(capture: capture)
    let tool = EchoLocationTool()

    let output = try await tool.call(
      arguments: #"{"location":"Seattle"}"#,
      messaging: messaging
    )

    #expect(output == "Seattle")
    #expect(capture.snapshot().isEmpty)
  }

  @Test("Validation failure calls validation hook with tool context")
  func validationFailureHook() async throws {
    let capture = ToolCallCapture()
    let messaging = RecordingToolCallMessaging(capture: capture)
    let tool = MinimumLengthLocationTool()
    let invalidArguments = #"{"location":"SF"}"#

    do {
      _ = try await tool.call(arguments: invalidArguments, messaging: messaging)
      Issue.record("Expected validation to fail")
    } catch CallError.invalidParameterValidation(let result) {
      #expect(!result.isValid)
    } catch {
      Issue.record("Expected CallError.invalidParameterValidation, got \(error)")
    }

    let failures = capture.validationSnapshot()
    #expect(failures.count == 1)
    #expect(failures.first?.toolName == "minimum_length_location")
    #expect(failures.first?.arguments == invalidArguments)
    #expect(!(failures.first?.result.isValid ?? true))
  }
}

private struct EchoLocationTool: Toolable {
  typealias Input = String

  let name = "echo_location"
  let description: String? = "Returns location from arguments"
  let strict = true

  var parameters: some JSONSchemaComponent<Input> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString()
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters: Input) async throws -> String {
    parameters
  }
}

private struct RecordingToolCallMessaging: ToolCallMessaging {
  let capture: ToolCallCapture

  func parsingFailed(_ context: ToolCallParsingFailedContext) {
    capture.append(context)
  }

  func validationFailed(_ context: ToolCallValidationFailedContext) {
    capture.appendValidation(context)
  }

  func parsingAndValidationFailed(_ context: ToolCallParsingAndValidationFailedContext) {
    capture.appendParsingAndValidation(context)
  }
}

private final class ToolCallCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var contexts: [ToolCallParsingFailedContext] = []
  private var validationContexts: [ToolCallValidationFailedContext] = []
  private var parsingAndValidationContexts: [ToolCallParsingAndValidationFailedContext] = []

  func append(_ context: ToolCallParsingFailedContext) {
    lock.lock()
    defer { lock.unlock() }
    contexts.append(context)
  }

  func snapshot() -> [ToolCallParsingFailedContext] {
    lock.lock()
    defer { lock.unlock() }
    return contexts
  }

  func appendValidation(_ context: ToolCallValidationFailedContext) {
    lock.lock()
    defer { lock.unlock() }
    validationContexts.append(context)
  }

  func validationSnapshot() -> [ToolCallValidationFailedContext] {
    lock.lock()
    defer { lock.unlock() }
    return validationContexts
  }

  func appendParsingAndValidation(_ context: ToolCallParsingAndValidationFailedContext) {
    lock.lock()
    defer { lock.unlock() }
    parsingAndValidationContexts.append(context)
  }

  func parsingAndValidationSnapshot() -> [ToolCallParsingAndValidationFailedContext] {
    lock.lock()
    defer { lock.unlock() }
    return parsingAndValidationContexts
  }
}

private struct MinimumLengthLocationTool: Toolable {
  typealias Input = String

  let name = "minimum_length_location"
  let description: String? = "Requires location to have at least three chars"
  let strict = true

  var parameters: some JSONSchemaComponent<Input> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString().minLength(3)
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters: Input) async throws -> String {
    parameters
  }
}
