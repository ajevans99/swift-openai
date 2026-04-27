public struct Reasoning: Sendable {
  public var effort: ReasoningEffort?
  public var summary: ReasoningSummary?

  public init(effort: ReasoningEffort? = nil, summary: ReasoningSummary? = nil) {
    self.effort = effort
    self.summary = summary
  }

  public init(openAPI: Components.Schemas.Reasoning) {
    self.effort = openAPI.effort.map(ReasoningEffort.init(openAPI:))
    self.summary = openAPI.summary.map { ReasoningSummary(openAPI: $0.rawValue) }
  }

  public func toOpenAPI() -> Components.Schemas.Reasoning {
    Components.Schemas.Reasoning(
      effort: effort?.toOpenAPI(),
      summary: summary?.rawValue
    )
  }
}

public enum ReasoningSummary: String, Codable, Sendable {
  case auto
  case concise
  case detailed

  public init(openAPI value: String) {
    self = ReasoningSummary(rawValue: value) ?? .auto
  }
}

public enum ReasoningEffort: String, Codable, Sendable {
  case none
  case minimal
  case low
  case medium
  case high
  case xhigh

  public init(openAPI value: Components.Schemas.ReasoningEffort) {
    switch value {
    case .none:
      self = .none
    case .minimal:
      self = .minimal
    case .low:
      self = .low
    case .medium:
      self = .medium
    case .high:
      self = .high
    case .xhigh:
      self = .xhigh
    }
  }

  public init(openAPI value: String) {
    self = ReasoningEffort(rawValue: value) ?? .medium
  }

  public func toOpenAPI() -> Components.Schemas.ReasoningEffort {
    switch self {
    case .none:
      return .none
    case .minimal:
      return .minimal
    case .low:
      return .low
    case .medium:
      return .medium
    case .high:
      return .high
    case .xhigh:
      return .xhigh
    }
  }
}
