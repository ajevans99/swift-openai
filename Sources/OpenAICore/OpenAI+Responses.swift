import Foundation
import Logging
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
    text: Components.Schemas.ResponseTextParam? = nil,
    toolChoice: Components.Schemas.ToolChoiceParam? = nil,
    tools: [Tool]? = nil,
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
        tools: tools?.map { $0.toOpenAPI() },
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

    switch output {
    case .ok(let ok):
      switch ok.body {
      case .json(let response):
        return Response(openAPI: response)
      case .textEventStream:
        throw CreateResponseError.incorrectEndpointForStreaming
      }
    case .undocumented(let statusCode, let payload):
      throw await makeUndocumentedResponseError(
        statusCode: statusCode,
        payload: payload,
        operation: "createResponse"
      )
    }
  }

  // MARK: Streaming

  @available(macOS 15.0, *)
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
    text: Components.Schemas.ResponseTextParam? = nil,
    toolChoice: Components.Schemas.ToolChoiceParam? = nil,
    tools: [Tool]? = nil,
    topP: Double? = nil,
    truncation: Truncation? = nil,
    user: String? = nil
  ) async throws -> any AsyncSequence<StreamingResponse, any Error> {
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
        tools: tools?.map { $0.toOpenAPI() },
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
    return try await streamCreateResponse(requestData)
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
    switch output {
    case .ok(let ok):
      switch ok.body {
      case .json:
        throw CreateResponseError.incorrectEndpointForNonStreaming
      case .textEventStream(let stream):
        body = stream
      }
    case .undocumented(let statusCode, let payload):
      throw await makeUndocumentedResponseError(
        statusCode: statusCode,
        payload: payload,
        operation: "streamCreateResponse"
      )
    }

    return AsyncThrowingStream { continuation in
      let logger = self.logger
      let task = Task {
        let decoder = JSONDecoder()
        var parser = StreamingSSEParser()

        do {
          for try await chunk in body {
            if Task.isCancelled {
              continuation.finish()
              return
            }

            for event in parser.consume(chunk) {
              if let response = Self.decodeStreamingResponse(
                from: event,
                decoder: decoder,
                logger: logger
              ) {
                continuation.yield(response)
              }
            }
          }

          for event in parser.finish() {
            if let response = Self.decodeStreamingResponse(
              from: event,
              decoder: decoder,
              logger: logger
            ) {
              continuation.yield(response)
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  private static func decodeStreamingResponse(
    from event: StreamingSSEEvent,
    decoder: JSONDecoder,
    logger: Logger
  ) -> StreamingResponse? {
    let eventName = event.event ?? "<none>"
    let eventID = event.id ?? "<none>"

    guard let payload = event.data else {
      let retryDescription = event.retry.map(String.init) ?? "none"
      logger.debug(
        "[OpenAICore] Received SSE control event event=\(eventName) id=\(eventID) retry=\(retryDescription)"
      )
      return nil
    }

    let payloadType = Self.streamEventType(from: payload) ?? "<unknown>"
    logger.debug(
      "[OpenAICore] Received SSE payload event=\(eventName) id=\(eventID) type=\(payloadType) bytes=\(payload.utf8.count)"
    )
    let payloadData = Data(payload.utf8)

    guard
      let decodedEvent = try? decoder.decode(
        Components.Schemas.ResponseStreamEvent.self,
        from: payloadData
      )
    else {
      logger.debug(
        "Skipping unsupported stream event payload type=\(payloadType): \(Self.truncatedStreamPayload(payload))"
      )
      return nil
    }

    return StreamingResponse(openAPI: decodedEvent)
  }

  private static func streamEventType(from payload: String) -> String? {
    guard let payloadData = payload.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: payloadData) else { return nil }
    guard let dictionary = object as? [String: Any] else { return nil }
    return dictionary["type"] as? String
  }

  private static func truncatedStreamPayload(_ payload: String, maxLength: Int = 800) -> String {
    guard payload.count > maxLength else { return payload }
    return String(payload.prefix(maxLength)) + "...<truncated>"
  }

  // MARK: - Get Response

  public func response(id: String) async throws -> Response {
    let input = Operations.GetResponse.Input(
      path: .init(responseId: id),
      headers: .init()
    )
    let output = try await openAPIClient.getResponse(input)

    switch output {
    case .ok(let ok):
      switch ok.body {
      case .json(let response):
        return Response(openAPI: response)
      }
    case .undocumented(let statusCode, let payload):
      throw await makeUndocumentedResponseError(
        statusCode: statusCode,
        payload: payload,
        operation: "getResponse"
      )
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
    case .undocumented(let statusCode, let payload):
      throw await makeUndocumentedResponseError(
        statusCode: statusCode,
        payload: payload,
        operation: "deleteResponse"
      )
    }
  }

  // MARK: Response Input Items

  public func responseInputItems(
    id: String,
    after: String? = nil,
    limit: Int? = nil,
    order: ListQueryItems.Order? = nil,
    include: [Includable]? = nil
  ) async throws -> ListInputItemsResponse {
    let query = ListQueryItems(
      after: after,
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

    switch output {
    case .ok(let ok):
      switch ok.body {
      case .json(let response):
        return ListInputItemsResponse(openAPI: response)
      }
    case .undocumented(let statusCode, let payload):
      throw await makeUndocumentedResponseError(
        statusCode: statusCode,
        payload: payload,
        operation: "listInputItems"
      )
    }
  }
}
