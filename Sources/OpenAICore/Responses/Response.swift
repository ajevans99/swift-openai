import Foundation
import OpenAPIRuntime

public struct Response: Sendable {
  public struct ResponseError: Error, Sendable {
    public let code: String
    public let message: String
  }

  public struct IncompleteDetails: Sendable {
    public enum Reason: String, Codable, Sendable {
      case maxOutputTokens
      case contentFilter
    }

    public let reason: Reason?

  }

  public enum Status: String, Sendable {
    case completed
    case failed
    case inProgress
    case incomplete
    case queued
    case cancelled

    public init(openAPI: Components.Schemas.Response.Value3Payload.StatusPayload) {
      switch openAPI {
      case .completed: self = .completed
      case .failed: self = .failed
      case .inProgress: self = .inProgress
      case .incomplete: self = .incomplete
      case .queued: self = .queued
      case .cancelled: self = .cancelled
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
      case .ResponseFormatText:
        self = .text
      case .ResponseFormatJsonObject:
        self = .jsonObject
      case .TextResponseFormatJsonSchema(let jsonSchema):
        self = .jsonSchema(
          name: jsonSchema.name,
          description: jsonSchema.description,
          schema: jsonSchema.schema.additionalProperties,
          strict: nil
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
  public let toolChoice: Components.Schemas.ToolChoiceParam?
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
    self.error = nil
    self.id = openAPI.value3.id
    self.incompleteDetails = nil
    self.instuctions = nil
    self.maxOutputTokens = nil
    self.metadata = nil
    self.model =
      openAPI.value2.model?.value1?.value1
      ?? openAPI.value2.model?.value1?.value2?.rawValue
      ?? openAPI.value2.model?.value2?.rawValue
    self.parallelToolCalls = openAPI.value3.parallelToolCalls
    self.previousResponseId = nil
    self.reasoning = nil
    self.serviceTier = nil
    self.status = openAPI.value3.status.map(Status.init)
    self.temperature = nil
    self.textFormat = openAPI.value2.text?.format.map(TextFormat.init)
    self.toolChoice = openAPI.value2.toolChoice
    self.tools = openAPI.value2.tools
    self.topP = nil
    self.truncation = nil
    self.usage = openAPI.value3.usage.map(Usage.init)
    self.user = nil
  }
}
