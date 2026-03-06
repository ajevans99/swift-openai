import Foundation

/// Policy describing how function-tool execution errors should be handled.
public enum ToolErrorPolicy: Sendable {
  /// Bubble up immediately – caller sees the throw.
  case failFast

  /// Feed the error string back to the assistant as the tool's output
  /// and let the model decide what to do next.
  case returnAsMessage

  /// Retry the tool once (or N times) before falling back
  case retry(count: Int = 1)

  /// Treat as "tool call failed", append a system message asking
  /// the assistant to clarify or choose another tool.
  case askAssistantToClarify(systemMessage: @Sendable (Error) -> String)
}

func executeToolWithPolicy(
  named name: String,
  policy: ToolErrorPolicy,
  operation: () async throws -> String
) async throws -> String {
  let maxAttempts: Int
  switch policy {
  case .retry(let count):
    maxAttempts = max(1, count + 1)
  default:
    maxAttempts = 1
  }

  var attempt = 0
  var lastError: Error?
  while attempt < maxAttempts {
    do {
      return try await operation()
    } catch {
      lastError = error
      attempt += 1
    }
  }

  guard let lastError else {
    throw ResponseSessionError.toolExecutionFailed(name: name)
  }

  switch policy {
  case .failFast, .retry:
    throw lastError
  case .returnAsMessage:
    return "Tool '\(name)' failed: \(String(describing: lastError))"
  case .askAssistantToClarify(let systemMessage):
    return systemMessage(lastError)
  }
}
