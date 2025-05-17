public struct Usage {
  public let inputTokens: Int
  public let inputTokensDetails: InputTokensDetails
  public let outputTokens: Int
  public let outputTokensDetails: OutputTokensDetails
  public let totalTokens: Int

  public init(openAPI: Components.Schemas.ResponseUsage) {
    self.inputTokens = openAPI.inputTokens
    self.inputTokensDetails = InputTokensDetails(openAPI: openAPI.inputTokensDetails)
    self.outputTokens = openAPI.outputTokens
    self.outputTokensDetails = OutputTokensDetails(openAPI: openAPI.outputTokensDetails)
    self.totalTokens = openAPI.totalTokens
  }

  public func toOpenAPI() -> Components.Schemas.ResponseUsage {
    .init(
      inputTokens: inputTokens,
      inputTokensDetails: inputTokensDetails.toOpenAPI(),
      outputTokens: outputTokens,
      outputTokensDetails: outputTokensDetails.toOpenAPI(),
      totalTokens: totalTokens
    )
  }
}

public struct InputTokensDetails {
  public let cachedTokens: Int

  public init(openAPI: Components.Schemas.ResponseUsage.InputTokensDetailsPayload) {
    self.cachedTokens = openAPI.cachedTokens
  }

  public func toOpenAPI() -> Components.Schemas.ResponseUsage.InputTokensDetailsPayload {
    .init(cachedTokens: cachedTokens)
  }
}

public struct OutputTokensDetails {
  public let reasoningTokens: Int

  public init(openAPI: Components.Schemas.ResponseUsage.OutputTokensDetailsPayload) {
    self.reasoningTokens = openAPI.reasoningTokens
  }

  public func toOpenAPI() -> Components.Schemas.ResponseUsage.OutputTokensDetailsPayload {
    .init(reasoningTokens: reasoningTokens)
  }
}
