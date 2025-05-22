import OpenAIFoundation

public enum Model: Sendable {
  case standard(Components.Schemas.ChatModel)
  case responseSpecific(Components.Schemas.ModelIdsResponses.Value2Payload)
  case custom(String)

  public func toOpenAPI() -> Components.Schemas.ModelIdsResponses {
    switch self {
    case .standard(let shared):
      Components.Schemas.ModelIdsResponses(value1: .init(value2: shared))
    case .responseSpecific(let response):
      Components.Schemas.ModelIdsResponses(value2: response)
    case .custom(let custom):
      Components.Schemas.ModelIdsResponses(value1: .init(value1: custom))
    }
  }
}

extension Model: ExpressibleByStringInterpolation {
  public init(stringLiteral value: String) {
    self = .custom(value)
  }
}
