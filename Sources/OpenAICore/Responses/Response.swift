import Foundation
import OpenAPIRuntime

public struct Response: Sendable {
  public struct ResponseError: Error, Sendable {
    public let code: String
    public let message: String

    public init(openAPI: Components.Schemas.ResponseError) {
      self.code = openAPI.code.rawValue
      self.message = openAPI.message
    }
  }

  public struct IncompleteDetails: Sendable {
    public enum Reason: String, Codable, Sendable {
      case maxOutputTokens
      case contentFilter
    }

    public let reason: Reason?

    public init(openAPI: Components.Schemas.Response.Value3Payload.IncompleteDetailsPayload) {
      self.reason =
        switch openAPI.reason {
        case .maxOutputTokens: .maxOutputTokens
        case .contentFilter: .contentFilter
        case nil: nil
        }
    }
  }

  public enum Status: String, Sendable {
    case completed
    case failed
    case inProgress
    case incomplete

    public init(openAPI: Components.Schemas.Response.Value3Payload.StatusPayload) {
      switch openAPI {
      case .completed: self = .completed
      case .failed: self = .failed
      case .inProgress: self = .inProgress
      case .incomplete: self = .incomplete
      }
    }
  }

  public enum TextFormat: Sendable {
    case text
    case jsonObject
    case jsonSchema(
      name: String,
      description: String?,
      schema: OpenAPIRuntime.OpenAPIObjectContainer,
      strict: Bool?
    )

    public init(openAPI: Components.Schemas.TextResponseFormatConfiguration) {
      switch openAPI {
      case .ResponseFormatText: self = .text
      case .ResponseFormatJsonObject: self = .jsonObject
      case .TextResponseFormatJsonSchema(let textResponse):
        self = .jsonSchema(
          name: textResponse.name,
          description: textResponse.description,
          schema: textResponse.schema.additionalProperties,
          strict: textResponse.strict
        )
      }
    }
  }

  public let createdAt: Double
  public let error: ResponseError?
  public let id: String
  public let incompleteDetails: IncompleteDetails?
  public let instuctions: String?
  public let maxOutputTokens: Int?
  public let metadata: [String: String]?
  public let model: String?
  public let object = "response"
  public let output: [OutputItem]
  public let parallelToolCalls: Bool
  public let previousResponseId: String?
  public let reasoning: Reasoning?
  public let serviceTier: ServiceTier?
  public let status: Status?
  public let temperature: Double?
  public let textFormat: TextFormat?
  public let toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload?
  public let tools: [Components.Schemas.Tool]?
  public let topP: Double?
  public let truncation: Truncation?
  public let usage: Usage?
  public let user: String?

  /// SDK only property based on official OpenAI Python SDK implementation
  /// https://github.com/openai/openai-python/blob/c097025779fc0bdc3389c047d4c060b5d7349f16/src/openai/types/responses/response.py#L211C5-L225C30
  public var outputText: String {
    var texts = [String]()

    for output in self.output {
      if case .message(let message) = output {
        for content in message.content {
          if case .text(let textContent) = content {
            texts.append(textContent.text)
          }
        }
      }
    }

    return texts.joined()
  }

  public init(openAPI: Components.Schemas.Response) {
    self.output = openAPI.value3.output.compactMap { OutputItem($0) }
    self.createdAt = openAPI.value3.createdAt
    self.error = openAPI.value3.error.map(ResponseError.init)
    self.id = openAPI.value3.id
    self.incompleteDetails = openAPI.value3.incompleteDetails.map(IncompleteDetails.init)
    self.instuctions = openAPI.value2.instructions
    self.maxOutputTokens = openAPI.value2.maxOutputTokens
    self.metadata = openAPI.value1.metadata?.additionalProperties
    self.model =
      openAPI.value2.model?.value1?.value1
      ?? openAPI.value2.model?.value1?.value2?.rawValue
      ?? openAPI.value2.model?.value2?.rawValue
    self.parallelToolCalls = openAPI.value3.parallelToolCalls
    self.previousResponseId = openAPI.value2.previousResponseId
    self.reasoning = openAPI.value2.reasoning.map(Reasoning.init)
    self.serviceTier = openAPI.value1.serviceTier.map(ServiceTier.init)
    self.status = openAPI.value3.status.map(Status.init)
    self.temperature = openAPI.value1.temperature
    self.textFormat = openAPI.value2.text?.format.map(TextFormat.init)
    self.toolChoice = openAPI.value2.toolChoice
    self.tools = openAPI.value2.tools
    self.topP = openAPI.value1.topP
    self.truncation = openAPI.value2.truncation.map(Truncation.init)
    self.usage = openAPI.value3.usage.map(Usage.init)
    self.user = openAPI.value1.user
  }
}
