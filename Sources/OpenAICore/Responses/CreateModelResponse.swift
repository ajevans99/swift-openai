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

  public init(
    metadata: [String: String]? = nil,
    temperature: Double? = nil,
    topP: Double? = nil,
    user: String? = nil,
    serviceTier: ServiceTier? = nil
  ) {
    self.metadata = metadata
    self.temperature = temperature
    self.topP = topP
    self.user = user
    self.serviceTier = serviceTier
  }

  public func toOpenAPI() -> Components.Schemas.CreateModelResponseProperties {
    Components.Schemas.CreateModelResponseProperties(
      value1: Components.Schemas.ModelResponseProperties(
        metadata: metadata.map { Components.Schemas.Metadata(additionalProperties: $0) },
        temperature: temperature,
        topP: topP,
        user: user,
        serviceTier: serviceTier?.toOpenAPI()
      )
    )
  }
}

public struct ResponseProperties: Sendable {
  public var previousResponseId: String?
  public var model: Model
  public var reasoning: Reasoning?
  public var maxOutputTokens: Int?
  public var instructions: String?
  public var text: Components.Schemas.ResponseProperties.TextPayload?
  public var tools: [Components.Schemas.Tool]?
  public var toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload?
  public var truncation: Truncation?

  public init(
    previousResponseId: String? = nil,
    model: Model,
    reasoning: Reasoning? = nil,
    maxOutputTokens: Int? = nil,
    instructions: String? = nil,
    text: Components.Schemas.ResponseProperties.TextPayload? = nil,
    tools: [Components.Schemas.Tool]? = nil,
    toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload? = nil,
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
      previousResponseId: previousResponseId,
      model: model.toOpenAPI(),
      reasoning: reasoning?.toOpenAPI(),
      maxOutputTokens: maxOutputTokens,
      instructions: instructions,
      text: text,
      tools: tools,
      toolChoice: toolChoice,
      truncation: truncation?.toOpenAPI()
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
      include: include?.map { $0.toOpenAPI() },
      parallelToolCalls: parallelToolCalls,
      store: store,
      stream: stream
    )
  }
}

public enum Includable: Sendable {
  case fileSearchResults
  case messageInputImage
  case computerCallOutputImage

  public func toOpenAPI() -> Components.Schemas.Includable {
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
