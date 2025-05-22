public enum ServiceTier: String, Codable, Sendable {
  case auto
  case `default`
  case flex

  public init(openAPI: Components.Schemas.ServiceTier) {
    switch openAPI {
    case .auto: self = .auto
    case ._default: self = .default
    case .flex: self = .flex
    }
  }

  public func toOpenAPI() -> Components.Schemas.ServiceTier {
    switch self {
    case .auto:
      return .auto
    case .default:
      return ._default
    case .flex:
      return .flex
    }
  }
}
