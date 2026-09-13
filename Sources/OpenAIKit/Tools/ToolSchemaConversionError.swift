import Foundation
import JSONSchema

/// A tool schema cannot be represented safely by the OpenAPI runtime.
public enum ToolSchemaConversionError: Error, Equatable, Sendable, LocalizedError {
  case unsupportedRootSchema
  case unsupportedNumber(JSONNumberLiteral)

  public var errorDescription: String? {
    switch self {
    case .unsupportedRootSchema:
      return "Boolean schemas are not supported at root level for tools."
    case .unsupportedNumber(let number):
      return
        "Tool schema number \(number.rawValue) cannot be represented losslessly as an OpenAPI Int or Double."
    }
  }
}
