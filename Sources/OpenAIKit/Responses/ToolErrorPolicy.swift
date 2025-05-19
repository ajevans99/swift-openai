import Foundation

public enum ToolErrorPolicy {
  /// Bubble up immediately – caller sees the throw.
  case failFast

  /// Feed the error string back to the assistant as the tool's output
  /// and let the model decide what to do next.
  case returnAsMessage

  /// Retry the tool once (or N times) before falling back
  case retry(count: Int = 1)

  /// Treat as "tool call failed", append a system message asking
  /// the assistant to clarify or choose another tool.
  case askAssistantToClarify(systemMessage: (Error) -> String)
}
