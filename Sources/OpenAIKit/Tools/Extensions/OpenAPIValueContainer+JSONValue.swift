import Foundation
import JSONSchema
import OpenAPIRuntime

extension OpenAPIValueContainer {
  init(jsonValue: JSONValue) {
    // Recursively turn a JSONValue into AnySendable-like types
    func any(from value: JSONValue) -> (any Sendable)? {
      switch value {
      case .null:
        return NSNull()
      case .string(let string):
        return string
      case .integer(let int):
        return int
      case .number(let double):
        return double
      case .boolean(let bool):
        return bool
      case .array(let array):
        return array.map { any(from: $0) }
      case .object(let object):
        return object.mapValues { any(from: $0) }
      }
    }

    let raw = any(from: jsonValue)
    try! self.init(unvalidatedValue: raw)
  }
}
