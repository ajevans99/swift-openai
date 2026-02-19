import Foundation

/// Errors thrown by ``ResponseSession``.
public enum ResponseSessionError: Error {
  /// A function tool call referenced an unknown tool name.
  case unknownTool(named: String)
  /// A streaming continuation needed a response ID but none was observed.
  case missingResponseIDForContinuation
  /// A tool execution failed without a captured underlying error.
  case toolExecutionFailed(name: String)
}
