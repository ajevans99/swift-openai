import Foundation
import OpenAPIRuntime

public struct CreateResponse: Sendable {
  public var modelProperties: CreateModelResponseProperties
  public var responseProperties: ResponseProperties
  public var inputPayload: CreateResponseInputPayload

  public init(
    modelProperties: CreateModelResponseProperties = CreateModelResponseProperties(),
    responseProperties: ResponseProperties,
    inputPayload: CreateResponseInputPayload
  ) {
    self.modelProperties = modelProperties
    self.responseProperties = responseProperties
    self.inputPayload = inputPayload
  }

  public func toOpenAPI() -> Components.Schemas.CreateResponse {
    Components.Schemas.CreateResponse(
      value1: modelProperties.toOpenAPI(),
      value2: responseProperties.toOpenAPI(),
      value3: inputPayload.toOpenAPI()
    )
  }
}

public struct CreateModelResponseProperties: Sendable {
  public var metadata: [String: String]?
  public var temperature: Double?
  public var topP: Double?
  public var user: String?
  public var serviceTier: ServiceTier?
  public var safetyIdentifier: String?
  public var promptCacheKey: String?

  public init(
    metadata: [String: String]? = nil,
    temperature: Double? = nil,
    topP: Double? = nil,
    user: String? = nil,
    serviceTier: ServiceTier? = nil,
    safetyIdentifier: String? = nil,
    promptCacheKey: String? = nil
  ) {
    self.metadata = metadata
    self.temperature = temperature
    self.topP = topP
    self.user = user
    self.serviceTier = serviceTier
    self.safetyIdentifier = safetyIdentifier
    self.promptCacheKey = promptCacheKey
  }

  public func toOpenAPI() -> Components.Schemas.CreateModelResponseProperties {
    Components.Schemas.CreateModelResponseProperties(
      value1: Components.Schemas.ModelResponseProperties(
        user: user,
        safetyIdentifier: safetyIdentifier,
        promptCacheKey: promptCacheKey
      ),
      value2: .init(topLogprobs: nil)
    )
  }
}

public struct ResponseProperties: Sendable {
  public var previousResponseId: String?
  public var model: Model
  public var reasoning: Reasoning?
  public var maxOutputTokens: Int?
  public var instructions: String?
  public var text: Components.Schemas.ResponseTextParam?
  public var tools: [Components.Schemas.Tool]?
  public var toolChoice: Components.Schemas.ToolChoiceParam?
  public var truncation: Truncation?

  public init(
    previousResponseId: String? = nil,
    model: Model,
    reasoning: Reasoning? = nil,
    maxOutputTokens: Int? = nil,
    instructions: String? = nil,
    text: Components.Schemas.ResponseTextParam? = nil,
    tools: [Components.Schemas.Tool]? = nil,
    toolChoice: Components.Schemas.ToolChoiceParam? = nil,
    truncation: Truncation? = nil
  ) {
    self.previousResponseId = previousResponseId
    self.model = model
    self.reasoning = reasoning
    self.maxOutputTokens = maxOutputTokens
    self.instructions = instructions
    self.text = text
    self.tools = tools
    self.toolChoice = toolChoice
    self.truncation = truncation
  }

  public func toOpenAPI() -> Components.Schemas.ResponseProperties {
    .init(
      model: model.toOpenAPI(),
      text: text,
      tools: tools,
      toolChoice: toolChoice
    )
  }
}

public struct CreateResponseInputPayload: Sendable {
  public var input: InputPayload
  public var include: [Includable]?
  public var parallelToolCalls: Bool?
  public var store: Bool?
  public var stream: Bool?

  public init(
    input: InputPayload,
    include: [Includable]? = nil,
    parallelToolCalls: Bool? = nil,
    store: Bool? = nil,
    stream: Bool? = nil
  ) {
    self.input = input
    self.include = include
    self.parallelToolCalls = parallelToolCalls
    self.store = store
    self.stream = stream
  }

  public func toOpenAPI() -> Components.Schemas.CreateResponse.Value3Payload {
    Components.Schemas.CreateResponse.Value3Payload(
      input: input.toOpenAPI(),
      stream: stream
    )
  }
}

public enum Includable: Sendable {
  case fileSearchResults
  case messageInputImage
  case computerCallOutputImage

  public func toOpenAPI() -> Components.Schemas.IncludeEnum {
    switch self {
    case .fileSearchResults:
      return .fileSearchCall_results
    case .messageInputImage:
      return .message_inputImage_imageUrl
    case .computerCallOutputImage:
      return .computerCallOutput_output_imageUrl
    }
  }
}
