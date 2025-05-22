public enum Truncation: Sendable {
  case auto
  case disabled

  public init(openAPI: Components.Schemas.ResponseProperties.TruncationPayload) {
    switch openAPI {
    case .auto: self = .auto
    case .disabled: self = .disabled
    }
  }

  public func toOpenAPI() -> Components.Schemas.ResponseProperties.TruncationPayload {
    switch self {
    case .auto: return .auto
    case .disabled: return .disabled
    }
  }
}
