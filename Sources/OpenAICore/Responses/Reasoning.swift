public struct Reasoning: Sendable {
  public var effort: ReasoningEffort?
  public var summary: ReasoningSummary?

  public init(openAPI: Components.Schemas.Reasoning) {
    self.effort = nil
    self.summary = nil
  }

  public func toOpenAPI() -> Components.Schemas.Reasoning {
    .init()
  }
}

public enum ReasoningSummary: String, Codable, Sendable {
  case auto
  case concise
  case detailed

  public init(openAPI _: String) { self = .auto }
}

public enum ReasoningEffort: String, Codable, Sendable {
  case low
  case medium
  case high

  public init(openAPI _: String) { self = .medium }
}
