public struct Reasoning: Sendable {
  public var effort: ReasoningEffort?
  public var summary: ReasoningSummary?

  public init(effort: ReasoningEffort? = nil, summary: ReasoningSummary? = nil) {
    self.effort = effort
    self.summary = summary
  }

  public init(openAPI: Components.Schemas.Reasoning) {
    self.effort = openAPI.effort.map { ReasoningEffort(openAPI: $0.rawValue) }
    self.summary = openAPI.summary.map { ReasoningSummary(openAPI: $0.rawValue) }
  }

  public func toOpenAPI() -> Components.Schemas.Reasoning {
    Components.Schemas.Reasoning(
      effort: effort.map { Components.Schemas.ReasoningEffort(rawValue: $0.rawValue)! },
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
  case low
  case medium
  case high

  public init(openAPI value: String) {
    self = ReasoningEffort(rawValue: value) ?? .medium
  }
}
