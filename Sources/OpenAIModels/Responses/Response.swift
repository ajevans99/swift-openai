import Foundation
import OpenAPIRuntime

public struct Response {
  public struct ResponseError: Error {
    public let code: String
    public let message: String

    public init(openAPI: Components.Schemas.ResponseError) {
      self.code = openAPI.code.rawValue
      self.message = openAPI.message
    }
  }

  public struct IncompleteDetails {
    public enum Reason: String, Codable {
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

  public enum Status: String {
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

  public let createdAt: Double
  public let error: ResponseError?
  public let id: String
  public let incompleteDetails: IncompleteDetails?
  public let instuctions: String?
  public let maxOutputTokens: Int?
  public let metadata: [String: String]?
  public let model: String?
  public let object = "response"
  public let parallelToolCalls: Bool
  public let previousResponseId: String?
  public let reasoning: Reasoning?
  public let serviceTier: ServiceTier?
  public let status: Status?
  public let temperature: Double?
  public let text: Components.Schemas.ResponseProperties.TextPayload?
  public let toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload?
  public let tools: [Components.Schemas.Tool]?
  public let topP: Double?
  public let truncation: Truncation?
  public let usage: Usage?
  public let user: String?

  public init(openAPI: Components.Schemas.Response) {
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
    self.text = openAPI.value2.text
    self.toolChoice = openAPI.value2.toolChoice
    self.tools = openAPI.value2.tools
    self.topP = openAPI.value1.topP
    self.truncation = openAPI.value2.truncation.map(Truncation.init)
    self.usage = openAPI.value3.usage.map(Usage.init)
    self.user = openAPI.value1.user
  }
}
