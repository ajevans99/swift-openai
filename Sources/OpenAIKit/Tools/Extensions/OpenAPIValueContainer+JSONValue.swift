import Foundation
import JSONSchema
import OpenAPIRuntime

extension OpenAPIValueContainer {
  init(jsonValue: JSONValue) throws {
    func any(from value: JSONValue) throws -> (any Sendable)? {
      switch value {
      case .null:
        return NSNull()
      case .string(let string):
        return string
      case .numberLiteral(let number):
        if let integer = value.integer {
          return integer
        }
        // Decimal is not supported by OpenAPIValueContainer. Accept Double only
        // when its JSON decimal spelling preserves the original numeric value.
        guard let double = value.number, try JSONNumberLiteral(double) == number else {
          throw ToolSchemaConversionError.unsupportedNumber(number)
        }
        return double
      case .boolean(let bool):
        return bool
      case .array(let array):
        return try array.map { try any(from: $0) }
      case .object(let object):
        return try Dictionary(
          uniqueKeysWithValues: object.map { ($0.key, try any(from: $0.value)) })
      }
    }

    let raw = try any(from: jsonValue)
    try self.init(unvalidatedValue: raw)
  }
}
