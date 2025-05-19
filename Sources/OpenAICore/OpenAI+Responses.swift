import OpenAIFoundation
import OpenAPIRuntime

extension OpenAI {
  // MARK: - Create Response

  public enum CreateResponseError: Error {
    /// Use the `streamCreateResponse` methods for streaming
    case incorrectEndpointForStreaming
    /// Use the `createResponse` methods for non-streaming
    case incorrectEndpointForNonStreaming
  }

  // MARK: Standard

  public func createResponse(
    input: InputPayload,
    model: Model,
    include: [Includable]? = nil,
    instructions: String? = nil,
    maxOutputTokens: Int? = nil,
    metadata: [String: String]? = nil,
    parallelToolCalls: Bool? = nil,
    previousResponseId: String? = nil,
    reasoning: Reasoning? = nil,
    serviceTier: ServiceTier? = nil,
    store: Bool? = nil,
    temperature: Double? = nil,
    text: Components.Schemas.ResponseProperties.TextPayload? = nil,
    toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload? = nil,
    tools: [Components.Schemas.Tool]? = nil,
    topP: Double? = nil,
    truncation: Truncation? = nil,
    user: String? = nil
  ) async throws -> Response {
    let requestData = CreateResponse(
      modelProperties: CreateModelResponseProperties(
        metadata: metadata,
        temperature: temperature,
        topP: topP,
        user: user,
        serviceTier: serviceTier
      ),
      responseProperties: ResponseProperties(
        previousResponseId: previousResponseId,
        model: model,
        reasoning: reasoning,
        maxOutputTokens: maxOutputTokens,
        instructions: instructions,
        text: text,
        tools: tools,
        toolChoice: toolChoice,
        truncation: truncation
      ),
      inputPayload: CreateResponseInputPayload(
        input: input,
        include: include,
        parallelToolCalls: parallelToolCalls,
        store: store,
        stream: false
      )
    )
    return try await createResponse(requestData)
  }

  public func createResponse(_ requestData: CreateResponse) async throws -> Response {
    let input = Operations.CreateResponse.Input(
      headers: .init(),
      body: .json(requestData.toOpenAPI())
    )

    guard requestData.inputPayload.stream != true else {
      throw CreateResponseError.incorrectEndpointForStreaming
    }

    let output = try await openAPIClient.createResponse(input)

    switch try output.ok.body {
    case .json(let response):
      return Response(openAPI: response)
    case .textEventStream:
      throw CreateResponseError.incorrectEndpointForStreaming
    }
  }

  // MARK: Streaming

  public func streamCreateResponse(
    input: InputPayload,
    model: Model,
    include: [Includable]? = nil,
    instructions: String? = nil,
    maxOutputTokens: Int? = nil,
    metadata: [String: String]? = nil,
    parallelToolCalls: Bool? = nil,
    previousResponseId: String? = nil,
    reasoning: Reasoning? = nil,
    serviceTier: ServiceTier? = nil,
    store: Bool? = nil,
    temperature: Double? = nil,
    text: Components.Schemas.ResponseProperties.TextPayload? = nil,
    toolChoice: Components.Schemas.ResponseProperties.ToolChoicePayload? = nil,
    tools: [Components.Schemas.Tool]? = nil,
    topP: Double? = nil,
    truncation: Truncation? = nil,
    user: String? = nil
  ) async throws -> Response {
    let requestData = CreateResponse(
      modelProperties: CreateModelResponseProperties(
        metadata: metadata,
        temperature: temperature,
        topP: topP,
        user: user,
        serviceTier: serviceTier
      ),
      responseProperties: ResponseProperties(
        previousResponseId: previousResponseId,
        model: model,
        reasoning: reasoning,
        maxOutputTokens: maxOutputTokens,
        instructions: instructions,
        text: text,
        tools: tools,
        toolChoice: toolChoice,
        truncation: truncation
      ),
      inputPayload: CreateResponseInputPayload(
        input: input,
        include: include,
        parallelToolCalls: parallelToolCalls,
        store: store,
        stream: true
      )
    )
    return try await createResponse(requestData)
  }

  @available(macOS 15.0, *)
  public func streamCreateResponse(_ requestData: CreateResponse) async throws
    -> any AsyncSequence<StreamingResponse, any Error>
  {
    let input = Operations.CreateResponse.Input(
      headers: .init(),
      body: .json(requestData.toOpenAPI())
    )

    guard requestData.inputPayload.stream == true else {
      throw CreateResponseError.incorrectEndpointForNonStreaming
    }

    let output = try await openAPIClient.createResponse(input)

    let body: HTTPBody
    switch try output.ok.body {
    case .json:
      throw CreateResponseError.incorrectEndpointForNonStreaming
    case .textEventStream(let stream):
      body = stream
    }

    return
      body
      .asDecodedJSONSequence(of: Components.Schemas.ResponseStreamEvent.self)
      .compactMap { event in
        StreamingResponse(openAPI: event)
      }
  }

  // MARK: - Get Response

  public func response(id: String) async throws -> Response {
    let input = Operations.GetResponse.Input(
      path: .init(responseId: id),
      headers: .init()
    )
    let output = try await openAPIClient.getResponse(input)

    switch try output.ok.body {
    case .json(let response):
      return Response(openAPI: response)
    }
  }

  // MARK: - Delete Response

  public enum DeleteResponseError: Error {
    case notFound
    case undocumented
  }

  public func deleteResponse(id: String) async throws {
    let input = Operations.DeleteResponse.Input(
      path: .init(responseId: id),
      headers: .init()
    )
    let output = try await openAPIClient.deleteResponse(input)

    switch output {
    case .ok:
      return
    case .notFound:
      throw DeleteResponseError.notFound
    case .undocumented:
      throw DeleteResponseError.undocumented
    }
  }

  // MARK: Response Input Items

  public func responseInputItems(
    id: String,
    after: String? = nil,
    before: String? = nil,
    limit: Int? = nil,
    order: ListQueryItems.Order? = nil,
    include: [Includable]? = nil
  ) async throws -> ListInputItemsResponse {
    let query = ListQueryItems(
      after: after,
      before: before,
      limit: limit,
      order: order,
      include: include
    )
    return try await responseInputItems(id: id, query: query)
  }

  public func responseInputItems(id: String, query: ListQueryItems) async throws
    -> ListInputItemsResponse
  {
    let input = Operations.ListInputItems.Input(
      path: .init(responseId: id),
      query: query.toOpenAPI(),
      headers: .init()
    )
    let output = try await openAPIClient.listInputItems(input)

    switch try output.ok.body {
    case .json(let response):
      return ListInputItemsResponse(openAPI: response)
    }
  }
}
