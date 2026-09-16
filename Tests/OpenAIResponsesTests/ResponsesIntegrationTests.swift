import CustomDump
import Foundation
import HTTPTypes
import JSONSchema
import JSONSchemaBuilder
import OpenAIResponses
import OpenAPIJSONRuntime
import OpenAPIRuntime
import Testing

struct ResponsesIntegrationTests {
  private typealias API = OpenAIResponsesAPI

  enum Failure: Error {
    case unexpectedResponse
    case unexpectedBodyRead
  }

  @Test("Text request convenience retains future model names and omits stream")
  func textRequestConvenience() throws {
    let body = API.Models.CreateResponse(input: "Hello", model: "future-model")
    let prepared = try API.Operations.createResponse.request(.init(body: body))
    expectNoDifference(
      prepared.body,
      try JSONValue.parse(#"{"input":"Hello","model":"future-model"}"#)
    )
  }

  @Test("Typed JSON request and response retain wire values", arguments: [false, true])
  func typedRequestAndResponse(explicitFalse: Bool) async throws {
    let fixture = try Self.fixture()
    let transport = RecordingTransport(replies: [Self.reply(body: fixture)])
    let baseURL = try #require(URL(string: "https://example.invalid/v1"))
    let client = try API.Client(
      transport: transport, apiKey: "recording-only", serverURL: baseURL
    )
    let body = API.Models.CreateResponse(
      metadata: .some(nil),
      model: .openapiJsonModelIdsShared(.string("gpt-5.5")),
      input: .string("Hello \u{4E16}\u{754C}"),
      instructions: .some(nil),
      stream: explicitFalse ? .some(.some(false)) : nil,
      max_output_tokens: 32
    )
    let output = try await client.createResponse(.init(body: body))
    guard case .status200(let response, let headers) = output else {
      throw Failure.unexpectedResponse
    }
    expectNoDifference(response.id, "resp_recording")
    expectNoDifference(response.outputText, "Hello \u{4E16}\u{754C}")
    expectNoDifference(headers[.contentType], "application/json")

    let requests = await transport.requests
    expectNoDifference(requests.count, 1)
    let request = try #require(requests.first)
    expectNoDifference(request.request.method, .post)
    expectNoDifference(request.request.path, "/responses")
    expectNoDifference(request.baseURL, baseURL)
    expectNoDifference(request.operationID, "createResponse")
    expectNoDifference(request.request.headerFields[.authorization], "Bearer recording-only")
    expectNoDifference(request.request.headerFields[.accept], "application/json")
    expectNoDifference(request.request.headerFields[.contentType], "application/json")
    let bytes = try #require(request.body)
    let value = try JSONValue.parse(String(decoding: bytes, as: UTF8.self))
    let expected = try JSONValue.parse(
      """
      {"metadata":null,"model":"gpt-5.5","input":"Hello \\u4e16\\u754c",
       "instructions":null,"max_output_tokens":32\(explicitFalse ? ",\"stream\":false" : "")}
      """
    )
    expectNoDifference(value, expected)
  }

  @Test("Response decoding and encoding retain allowed extras and exact numbers")
  func responseRoundTrip() async throws {
    let fixture = try Self.fixture()
    let transport = RecordingTransport(replies: [Self.reply(body: fixture)])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let output = try await client.createResponse(.init(body: Self.requestBody()))
    guard case .status200(let response, _) = output else {
      throw Failure.unexpectedResponse
    }
    let encoded = try API.Models.createResponseResponse200JSON(response)
    let original = try JSONValue.parse(String(decoding: fixture, as: UTF8.self))
    expectNoDifference(encoded, original)
  }

  @Test("Request model round trips unknown fields without narrowing their JSON numbers")
  func requestRoundTrip() async throws {
    let original = try JSONValue.parse(
      """
      {"model":"future-model","input":"Hello","stream":false,"instructions":null,
       "future_integer":123456789012345678901234567890,
       "future_decimal":1.0000000000000000001,"future_null":null,
       "unmodeledProperties":{"nested":[1.0000000000000000001,null]},
       "metadata":{"purpose":"recording"}}
      """
    )
    let typed = try API.Models.createResponseBodySchema.parseAndValidate(original)
    let prepared = try API.Operations.createResponse.request(.init(body: typed))
    expectNoDifference(prepared.body, original)

    let transport = RecordingTransport(replies: [Self.reply(body: try Self.fixture())])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    _ = try await client.createResponse(.init(body: typed))
    let requests = await transport.requests
    let bytes = try #require(requests.first?.body)
    let wireValue = try JSONValue.parse(String(decoding: bytes, as: UTF8.self))
    expectNoDifference(wireValue, original)
  }

  @Test("Typed function tools, calls, and tool replies use the generated operation")
  func functionToolRoundTrip() async throws {
    let fixture = try JSONValue.parse(String(decoding: Self.fixture(), as: UTF8.self))
    var object = try #require(fixture.object)
    var output = try #require(object["output"]?.array)
    output.append(
      try JSONValue.parse(
        """
        {"type":"function_call","id":"fc_recording","call_id":"call_recording",
         "name":"lookup","arguments":"{}","status":"completed"}
        """
      )
    )
    object["output"] = .array(output)
    let original = JSONValue.object(object)
    let responseBody = Data(try original.serialized().utf8)
    let transport = RecordingTransport(replies: [
      Self.reply(body: responseBody), Self.reply(body: try Self.fixture()),
    ])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let tool = API.Models.FunctionTool(
      type: .function, name: "lookup",
      parameters: [
        "type": .string("object"), "properties": .object([:]),
        "additionalProperties": .boolean(false), "required": .array([]),
      ],
      strict: true
    )
    let body = API.Models.CreateResponse(
      model: .openapiJsonModelIdsShared(.string("future-model")),
      tools: [.functionTool(tool)], input: .string("Look it up")
    )
    let result = try await client.createResponse(.init(body: body))
    guard case .status200(let response, _) = result,
      case .functionToolCall(let call) = response.output.last
    else {
      throw Failure.unexpectedResponse
    }
    expectNoDifference(call.call_id, "call_recording")
    expectNoDifference(call.name, "lookup")
    expectNoDifference(call.arguments, "{}")
    expectNoDifference(response.outputText, "Hello \u{4E16}\u{754C}")
    expectNoDifference(try API.Models.createResponseResponse200JSON(response), original)

    let replyJSON = try JSONValue.parse(
      """
      {"model":"future-model","previous_response_id":"resp_recording",
       "input":[{"type":"function_call_output","call_id":"call_recording","output":"Found it"}]}
      """
    )
    let reply = try API.Models.createResponseBodySchema.parseAndValidate(replyJSON)
    _ = try await client.createResponse(.init(body: reply))
    let requests = await transport.requests
    expectNoDifference(requests.count, 2)
    let first = try #require(requests.first?.body)
    expectNoDifference(
      try JSONValue.parse(String(decoding: first, as: UTF8.self)),
      try JSONValue.parse(
        """
        {"model":"future-model","input":"Look it up","tools":[
          {"type":"function","name":"lookup","strict":true,
           "parameters":{"type":"object","properties":{},"additionalProperties":false,"required":[]}}
        ]}
        """
      )
    )
    let last = try #require(requests.last?.body)
    expectNoDifference(try JSONValue.parse(String(decoding: last, as: UTF8.self)), replyJSON)
  }

  @Test("Streaming true and explicit null fail before transport", arguments: [false, true])
  func rejectsStreamingBeforeTransport(explicitNull: Bool) async throws {
    let transport = RecordingTransport()
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let stream: Bool?? = explicitNull ? .some(nil) : .some(.some(true))
    let body = Self.requestBody(stream: stream)
    await #expect(throws: ParseAndValidateIssue.self) {
      try await client.createResponse(.init(body: body))
    }
    let requests = await transport.requests
    expectNoDifference(requests.count, 0)
  }

  @Test("Original request constraints also fail before transport")
  func rejectsOriginalSchemaViolation() async throws {
    let transport = RecordingTransport()
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let body = API.Models.CreateResponse(
      top_p: 3,
      model: .openapiJsonModelIdsShared(.string("gpt-5.5")),
      input: .string("Hello")
    )
    await #expect(throws: ParseAndValidateIssue.self) {
      try await client.createResponse(.init(body: body))
    }
    let requests = await transport.requests
    expectNoDifference(requests.count, 0)
  }

  @Test("Actual SSE is rejected before the response body is iterated")
  func rejectsSSEBeforeBodyRead() async throws {
    let probe = BodyReadProbe()
    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "text/event-stream"
    let transport = RecordingTransport(replies: [
      .init(
        response: response,
        body: HTTPBody(UnreadBody(probe: probe), length: .unknown, iterationBehavior: .single)
      )
    ])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    await #expect(throws: JSONClientError.unexpectedContentType("text/event-stream")) {
      try await client.createResponse(.init(body: Self.requestBody()))
    }
    let readCount = await probe.readCount
    expectNoDifference(readCount, 0)
  }

  @Test("Cancellation propagates while the actual response body is waiting")
  func cancelsWaitingResponseBody() async throws {
    let (reads, continuation) = AsyncStream<Void>.makeStream()
    let body = HTTPBody(
      WaitingBody(reads: continuation), length: .unknown, iterationBehavior: .single
    )
    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "application/json"
    let transport = RecordingTransport(replies: [.init(response: response, body: body)])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let request = Task {
      defer { continuation.finish() }
      return try await client.createResponse(.init(body: Self.requestBody()))
    }
    var iterator = reads.makeAsyncIterator()
    let read: Void? = await iterator.next()
    request.cancel()
    #expect(read != nil)
    await #expect(throws: CancellationError.self) {
      try await request.value
    }
    let requests = await transport.requests
    expectNoDifference(requests.count, 1)
  }

  @Test("An already cancelled task never reaches transport")
  func cancelsBeforeTransport() async throws {
    let transport = RecordingTransport()
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let request = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await client.createResponse(.init(body: Self.requestBody()))
    }
    await #expect(throws: CancellationError.self) {
      try await request.value
    }
    let requests = await transport.requests
    expectNoDifference(requests.count, 0)
  }

  @Test("Documented error statuses decode typed error bodies", arguments: [429, 503])
  func documentedErrors(status: Int) async throws {
    let body = Data(
      #"{"error":{"code":"rate_limit_exceeded","message":"Try later","param":null,"type":"rate_limit_error"}}"#
        .utf8
    )
    let transport = RecordingTransport(replies: [Self.reply(status: status, body: body)])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    let output = try await client.createResponse(.init(body: Self.requestBody()))
    switch output {
    case .status429(let error, _) where status == 429,
      .status503(let error, _) where status == 503:
      expectNoDifference(error.error.message, "Try later")
      expectNoDifference(error.error.code, "rate_limit_exceeded")
    default:
      throw Failure.unexpectedResponse
    }
  }

  @Test("Undocumented status is not replaced by a media-type failure")
  func undocumentedStatusPrecedence() async throws {
    let transport = RecordingTransport(replies: [
      Self.reply(status: 418, contentType: "text/plain", body: Data("teapot".utf8))
    ])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    await #expect(throws: JSONClientError.unexpectedStatus(418)) {
      try await client.createResponse(.init(body: Self.requestBody()))
    }
  }

  @Test("A schema-invalid output union variant is not silently dropped")
  func rejectsInvalidOutputVariant() async throws {
    let fixture = try JSONValue.parse(String(decoding: Self.fixture(), as: UTF8.self))
    var object = try #require(fixture.object)
    var output = try #require(object["output"]?.array)
    var message = try #require(output.first?.object)
    message["type"] = .string("unknown_output_variant")
    output[0] = .object(message)
    object["output"] = .array(output)
    let body = Data(try JSONValue.object(object).serialized().utf8)
    let transport = RecordingTransport(replies: [Self.reply(body: body)])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    await #expect(throws: ParseAndValidateIssue.self) {
      try await client.createResponse(.init(body: Self.requestBody()))
    }
  }

  @Test("A missing required response field fails original schema validation")
  func rejectsMissingResponseID() async throws {
    let fixture = try JSONValue.parse(String(decoding: Self.fixture(), as: UTF8.self))
    var object = try #require(fixture.object)
    object.removeValue(forKey: "id")
    let body = Data(try JSONValue.object(object).serialized().utf8)
    let transport = RecordingTransport(replies: [Self.reply(body: body)])
    let client = try API.Client(transport: transport, apiKey: "recording-only")
    await #expect(throws: ParseAndValidateIssue.self) {
      try await client.createResponse(.init(body: Self.requestBody()))
    }
  }

  private static func requestBody(stream: Bool?? = nil) -> API.Models.CreateResponse {
    .init(
      model: .openapiJsonModelIdsShared(.string("gpt-5.5")),
      input: .string("Hello"),
      stream: stream
    )
  }

  private static func fixture() throws -> Data {
    let url = try #require(
      Bundle.module.url(forResource: "response", withExtension: "json", subdirectory: "Fixtures")
    )
    return try Data(contentsOf: url)
  }

  private static func reply(
    status: Int = 200,
    contentType: String = "application/json",
    body: Data
  ) -> RecordingTransport.Reply {
    var response = HTTPResponse(status: .init(code: status))
    response.headerFields[.contentType] = contentType
    return .init(response: response, body: HTTPBody(body))
  }
}

private actor BodyReadProbe {
  private(set) var readCount = 0

  func recordRead() {
    readCount += 1
  }
}

private struct UnreadBody: AsyncSequence, Sendable {
  typealias Element = ArraySlice<UInt8>
  let probe: BodyReadProbe

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(probe: probe)
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    let probe: BodyReadProbe

    mutating func next() async throws -> ArraySlice<UInt8>? {
      await probe.recordRead()
      throw ResponsesIntegrationTests.Failure.unexpectedBodyRead
    }
  }
}

private struct WaitingBody: AsyncSequence, Sendable {
  typealias Element = ArraySlice<UInt8>
  let reads: AsyncStream<Void>.Continuation

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(reads: reads)
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    let reads: AsyncStream<Void>.Continuation

    mutating func next() async throws -> ArraySlice<UInt8>? {
      reads.yield()
      try await Task.sleep(for: .seconds(60))
      throw ResponsesIntegrationTests.Failure.unexpectedBodyRead
    }
  }
}
