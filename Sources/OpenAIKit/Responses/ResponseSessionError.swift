import Foundation

/// Errors thrown by ``ResponseSession``.
public enum ResponseSessionError: Error {
  /// A function tool call referenced an unknown tool name.
  case unknownTool(named: String)
  /// A streaming continuation needed a response ID but none was observed.
  case missingResponseIDForContinuation
  /// A provider stream ended without a completed, failed, incomplete, or error event.
  case missingTerminalEvent
  /// A tool execution failed without a captured underlying error.
  case toolExecutionFailed(name: String)
  /// A bounded stream channel could not retain another event.
  case bufferOverflow(channel: String, capacity: Int)
}
