import Foundation
import OpenAPIRuntime

public struct ImagesResponse: Sendable {
  public struct Image: Sendable {
    public let url: String?
    public let b64Json: String?
    public let revisedPrompt: String?

    public init(openAPI: Components.Schemas.Image) {
      self.url = openAPI.url
      self.b64Json = openAPI.b64Json
      self.revisedPrompt = openAPI.revisedPrompt
    }
  }

  public struct Usage: Sendable {
    public struct InputTokensDetails: Sendable {
      public let textTokens: Int
      public let imageTokens: Int

      public init(openAPI: Components.Schemas.ImagesResponse.UsagePayload.InputTokensDetailsPayload)
      {
        self.textTokens = openAPI.textTokens
        self.imageTokens = openAPI.imageTokens
      }
    }

    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let inputTokensDetails: InputTokensDetails

    public init(openAPI: Components.Schemas.ImagesResponse.UsagePayload) {
      self.totalTokens = openAPI.totalTokens
      self.inputTokens = openAPI.inputTokens
      self.outputTokens = openAPI.outputTokens
      self.inputTokensDetails = InputTokensDetails(openAPI: openAPI.inputTokensDetails)
    }
  }

  public let created: Int
  public let data: [Image]
  public let usage: Usage?

  public init(openAPI: Components.Schemas.ImagesResponse) {
    self.created = openAPI.created
    self.data = openAPI.data?.map(Image.init) ?? []
    self.usage = openAPI.usage.map(Usage.init)
  }
}
