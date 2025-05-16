public enum InputPayload {
  case text(String)
  case items([InputItem])

  public func toOpenAPI() -> Components.Schemas.CreateResponse.Value3Payload.InputPayload {
    switch self {
    case .text(let string):
      return .case1(string)
    case .items(let items):
      return .case2(items.map { $0.toOpenAPI() })
    }
  }
}

extension InputPayload: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .text(value)
  }
}

extension InputPayload: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self = .text(stringInterpolation.description)
  }
}

extension InputPayload: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: InputItem...) {
    self = .items(elements)
  }
}
