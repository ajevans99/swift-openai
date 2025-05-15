import JSONSchema
import OpenAPIRuntime

extension OpenAPIValueContainer {
  init(jsonValue: JSONValue) {
    // We can safely unwrap here because we know the JSONValue types (Bool, String, Double, etc) are supported
    switch jsonValue {
    case .boolean(let bool):
      try! self.init(unvalidatedValue: bool)
    case .object(let dict):
      try! self.init(unvalidatedValue: dict)
    case .string(let string):
      try! self.init(unvalidatedValue: string)
    case .number(let number):
      try! self.init(unvalidatedValue: number)
    case .integer(let int):
      try! self.init(unvalidatedValue: int)
    case .array(let array):
      try! self.init(unvalidatedValue: array)
    case .null:
      try! self.init(unvalidatedValue: nil)
    }
  }
}
