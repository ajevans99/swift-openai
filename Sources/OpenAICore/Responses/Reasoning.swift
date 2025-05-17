public struct Reasoning {
  public var effort: ReasoningEffort?
  public var summary: ReasoningSummary?

  public init(openAPI: Components.Schemas.Reasoning) {
    self.effort = openAPI.effort.map { ReasoningEffort(openAPI: $0) }
    self.summary = openAPI.summary.map { ReasoningSummary(openAPI: $0) }
  }

  public func toOpenAPI() -> Components.Schemas.Reasoning {
    .init(
      effort: effort?.toOpenAPI(),
      summary: summary?.toOpenAPI()
    )
  }
}

public enum ReasoningSummary: String, Codable {
  case auto
  case concise
  case detailed

  public init(openAPI: Components.Schemas.Reasoning.SummaryPayload) {
    switch openAPI {
    case .auto: self = .auto
    case .concise: self = .concise
    case .detailed: self = .detailed
    }
  }

  public func toOpenAPI() -> Components.Schemas.Reasoning.SummaryPayload {
    switch self {
    case .auto: return .auto
    case .concise: return .concise
    case .detailed: return .detailed
    }
  }
}

public enum ReasoningEffort: String, Codable {
  case low
  case medium
  case high

  public init(openAPI: Components.Schemas.ReasoningEffort) {
    switch openAPI {
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    }
  }

  public func toOpenAPI() -> Components.Schemas.ReasoningEffort {
    switch self {
    case .low: return .low
    case .medium: return .medium
    case .high: return .high
    }
  }
}
