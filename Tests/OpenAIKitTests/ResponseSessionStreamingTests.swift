import CustomDump
import Foundation
import HTTPTypes
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import OpenAPIRuntime
import Testing

@Suite("ResponseSession Streaming")
struct ResponseSessionStreamingTests {
  @Test("Text plugin receives deltas/completion while raw stream remains available")
  func textPluginAndRawStream() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_text_1", sequenceNumber: 0),
          Self.textDeltaEvent(
            itemID: "msg_1",
            outputIndex: 0,
            contentIndex: 0,
            delta: "Hello ",
            sequenceNumber: 1
          ),
          Self.textDoneEvent(
            itemID: "msg_1",
            outputIndex: 0,
            contentIndex: 0,
            text: "Hello world!",
            sequenceNumber: 2
          ),
          Self.completedEvent(responseID: "resp_text_1", sequenceNumber: 3),
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)

    let handle = try await session.stream(
      "Say hello",
      plugins: TextPlugin()
    )
    let textChannel = handle.pluginEvents

    let textEvents = try await Self.collect(textChannel.events)
    let rawValues = try await Self.collectRawValues(handle.raw)

    expectNoDifference(
      textEvents,
      [
        .delta("Hello "),
        .completed("Hello world!"),
      ]
    )
    expectNoDifference(
      rawValues,
      [
        "response.created",
        "response.output_text.delta",
        "response.output_text.done",
        "response.completed",
      ]
    )
  }

  @Test("Image plugin receives partial and final image events")
  func imagePluginEvents() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_image_1", sequenceNumber: 0),
          Self.imagePartialEvent(
            itemID: "img_1",
            outputIndex: 0,
            partialImageIndex: 0,
            partialImageBase64: "cGFydGlhbA==",
            sequenceNumber: 1
          ),
          Self.imageOutputItemDoneEvent(
            itemID: "img_1",
            outputIndex: 0,
            status: "completed",
            resultBase64: "ZmluYWw=",
            sequenceNumber: 2
          ),
          Self.completedEvent(responseID: "resp_image_1", sequenceNumber: 3),
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)

    let handle = try await session.stream(
      "Draw a cat",
      plugins: ImagePlugin()
    )
    let imageChannel = handle.pluginEvents

    let imageEvents = try await Self.collect(imageChannel.events)
    expectNoDifference(
      imageEvents,
      [
        .partial(
          itemID: "img_1",
          outputIndex: 0,
          base64: "cGFydGlhbA==",
          partialIndex: 0,
          sequenceNumber: 1
        ),
        .completed(
          itemID: "img_1",
          status: "completed",
          resultBase64: "ZmluYWw="
        ),
      ]
    )
  }

  @Test("Tool orchestrator executes plugin-local tools and continues turn")
  func toolOrchestratorPluginLocalRegistration() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"San Francisco"}"#
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_tool_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_1",
            callID: "call_weather_1",
            name: "get_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_tool_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_tool_2", sequenceNumber: 0),
          Self.textDoneEvent(
            itemID: "msg_2",
            outputIndex: 0,
            contentIndex: 0,
            text: "Forecast delivered.",
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_tool_2", sequenceNumber: 2),
        ]),
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let orchestrator = ToolOrchestratorPlugin(
      tools: [WeatherEchoTool(prefix: "plugin-local")]
    )

    let handle = try await session.stream(
      "What's the weather?",
      plugins: TextPlugin(), orchestrator
    )
    let (textChannel, toolChannel) = handle.pluginEvents

    let textEvents = try await Self.collect(textChannel.events)
    let toolEvents = try await Self.collect(toolChannel.events)

    expectNoDifference(
      textEvents,
      [.completed("Forecast delivered.")]
    )
    expectNoDifference(
      toolEvents,
      [
        .executed(
          name: "get_weather",
          arguments: arguments,
          callID: "call_weather_1",
          output: "plugin-local:San Francisco"
        )
      ]
    )

    let requestBodies = await transport.requestBodies()
    #expect(requestBodies.count == 2)
    #expect(requestBodies[1].contains(#""type" : "function_call_output""#))
    #expect(requestBodies[1].contains(#""call_id" : "call_weather_1""#))
  }

  @Test("Tool orchestrator falls back to session-level tool registration")
  func toolOrchestratorSessionFallbackRegistration() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"Seattle"}"#
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_fallback_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_fallback",
            callID: "call_weather_fallback",
            name: "get_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_fallback_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_fallback_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_fallback_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(transport: transport)
    await session.register(tool: WeatherEchoTool(prefix: "session-fallback"))

    let handle = try await session.stream(
      "Use fallback tool lookup",
      plugins: ToolOrchestratorPlugin()
    )
    let toolChannel = handle.pluginEvents

    let toolEvents = try await Self.collect(toolChannel.events)
    expectNoDifference(
      toolEvents,
      [
        .executed(
          name: "get_weather",
          arguments: arguments,
          callID: "call_weather_fallback",
          output: "session-fallback:Seattle"
        )
      ]
    )
  }

  @Test("Unknown tool propagates as stream failure")
  func unknownToolFailure() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_missing_tool", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_missing",
            callID: "call_missing",
            name: "unknown_tool",
            arguments: #"{"location":"Nowhere"}"#,
            outputIndex: 0,
            sequenceNumber: 1
          ),
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let handle = try await session.stream(
      "Trigger missing tool",
      plugins: ToolOrchestratorPlugin()
    )

    do {
      _ = try await Self.collectRawValues(handle.raw)
      Issue.record("Expected stream to fail with unknown tool")
    } catch let error as ResponseSessionError {
      switch error {
      case .unknownTool(let name):
        #expect(name == "unknown_tool")
      default:
        Issue.record("Expected unknownTool error, got \(error)")
      }
    }
  }

  @Test("Tool orchestrator plugin-local returnAsMessage keeps stream alive")
  func toolOrchestratorPluginLocalReturnAsMessage() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"Denver"}"#
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_tool_err_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_err_1",
            callID: "call_err_1",
            name: "always_fail_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_tool_err_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_tool_err_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_tool_err_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let orchestrator = ToolOrchestratorPlugin(
      tools: [AlwaysFailWeatherTool()],
      errorPolicy: .returnAsMessage
    )

    let handle = try await session.stream(
      "Trigger a tool failure",
      plugins: orchestrator
    )
    let toolChannel = handle.pluginEvents
    let events = try await Self.collect(toolChannel.events)

    #expect(events.count == 1)
    if case .executed(_, _, _, let output) = events[0] {
      #expect(output.contains("Tool 'always_fail_weather' failed:"))
    } else {
      Issue.record("Expected executed event")
    }

    let requestBodies = await transport.requestBodies()
    #expect(requestBodies.count == 2)
    #expect(requestBodies[1].contains(#""type" : "function_call_output""#))
    #expect(requestBodies[1].contains("Tool 'always_fail_weather' failed:"))
  }

  @Test("Tool orchestrator plugin-local retry eventually succeeds")
  func toolOrchestratorPluginLocalRetry() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"Austin"}"#
    let attempts = AttemptCounter()
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_retry_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_retry_1",
            callID: "call_retry_1",
            name: "flaky_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_retry_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_retry_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_retry_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let orchestrator = ToolOrchestratorPlugin(
      tools: [FlakyWeatherTool(attempts: attempts, failUntilAttempt: 2)],
      errorPolicy: .retry(count: 2)
    )

    let handle = try await session.stream(
      "Try tool retries",
      plugins: orchestrator
    )
    let toolChannel = handle.pluginEvents
    let events = try await Self.collect(toolChannel.events)

    expectNoDifference(
      events,
      [
        .executed(
          name: "flaky_weather",
          arguments: arguments,
          callID: "call_retry_1",
          output: "flaky-success:Austin:attempt_3"
        )
      ]
    )
    let recordedAttempts = await attempts.value()
    #expect(recordedAttempts == 3)
  }

  @Test("Tool orchestrator fallback honors plugin error policy override")
  func toolOrchestratorFallbackErrorPolicyOverride() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"Chicago"}"#
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_override_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_override_1",
            callID: "call_override_1",
            name: "always_fail_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_override_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_override_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_override_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(
      transport: transport,
      errorPolicy: .failFast
    )
    await session.register(tool: AlwaysFailWeatherTool())

    let handle = try await session.stream(
      "Use session fallback with plugin policy override",
      plugins: ToolOrchestratorPlugin(
        errorPolicy: .askAssistantToClarify { _ in
          "Tool failed. Ask the user to verify location and retry."
        }
      )
    )
    let toolChannel = handle.pluginEvents
    let events = try await Self.collect(toolChannel.events)

    expectNoDifference(
      events,
      [
        .executed(
          name: "always_fail_weather",
          arguments: arguments,
          callID: "call_override_1",
          output: "Tool failed. Ask the user to verify location and retry."
        )
      ]
    )
  }

  @Test("Tool orchestrator fallback uses session policy when override is omitted")
  func toolOrchestratorFallbackUsesSessionPolicyByDefault() async throws {
    guard #available(macOS 15.0, *) else { return }
    let arguments = #"{"location":"Phoenix"}"#
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_session_policy_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_session_policy_1",
            callID: "call_session_policy_1",
            name: "always_fail_weather",
            arguments: arguments,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_session_policy_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_session_policy_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_session_policy_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(
      transport: transport,
      errorPolicy: .returnAsMessage
    )
    await session.register(tool: AlwaysFailWeatherTool())

    let handle = try await session.stream(
      "Use session policy with orchestrator fallback",
      plugins: ToolOrchestratorPlugin()
    )
    let toolChannel = handle.pluginEvents
    let events = try await Self.collect(toolChannel.events)

    #expect(events.count == 1)
    if case .executed(_, _, _, let output) = events[0] {
      #expect(output.contains("Tool 'always_fail_weather' failed:"))
    } else {
      Issue.record("Expected executed event")
    }
  }

  @Test("Plugin channels track dropped events when consumer is slower than producer")
  func droppedCountTracking() async throws {
    guard #available(macOS 15.0, *) else { return }
    let deltaEvents = (0..<400).map { index in
      Self.textDeltaEvent(
        itemID: "msg_drop",
        outputIndex: 0,
        contentIndex: 0,
        delta: "chunk_\(index)",
        sequenceNumber: index + 1
      )
    }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload(
          [Self.createdEvent(responseID: "resp_drop", sequenceNumber: 0)]
            + deltaEvents
            + [
              Self.textDoneEvent(
                itemID: "msg_drop",
                outputIndex: 0,
                contentIndex: 0,
                text: "done",
                sequenceNumber: 500
              ),
              Self.completedEvent(responseID: "resp_drop", sequenceNumber: 501),
            ]
        )
      ]
    )
    let session = try Self.makeSession(transport: transport)

    let handle = try await session.stream(
      "Generate many chunks",
      plugins: TextPlugin()
    )
    let textChannel = handle.pluginEvents

    _ = try await Self.collectRawValues(handle.raw)
    #expect(textChannel.droppedCount() > 0)
  }

  @Test("Raw-only stream API emits raw response events")
  func rawOnlyStreaming() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_raw_1", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_raw_1", sequenceNumber: 1),
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)

    let rawStream = try await session.streamRaw("Only raw")

    let rawValues = try await Self.collectRawValues(rawStream)
    expectNoDifference(
      rawValues,
      [
        "response.created",
        "response.completed",
      ]
    )
  }
}

extension ResponseSessionStreamingTests {
  private static func makeSession(
    transport: some ClientTransport,
    errorPolicy: ToolErrorPolicy = .failFast
  ) throws -> ResponseSession {
    let client = try OpenAI(transport: transport, apiKey: "test-key")
    return ResponseSession(
      client: client,
      model: .custom("gpt-5.2"),
      errorPolicy: errorPolicy
    )
  }

  private static func collect<S: AsyncSequence>(_ sequence: S) async throws -> [S.Element] {
    var output: [S.Element] = []
    for try await element in sequence {
      output.append(element)
    }
    return output
  }

  private static func collectRawValues(
    _ sequence: AsyncThrowingStream<StreamingResponse, Error>
  ) async throws -> [String] {
    var values: [String] = []
    for try await event in sequence {
      values.append(event.value)
    }
    return values
  }

  private static func ssePayload(_ events: [String]) -> String {
    events.map { "data: \($0)\n\n" }.joined()
  }

  private static func createdEvent(responseID: String, sequenceNumber: Int) -> String {
    jsonString([
      "type": "response.created",
      "response": responseObject(id: responseID, status: "in_progress"),
      "sequence_number": sequenceNumber,
    ])
  }

  private static func completedEvent(responseID: String, sequenceNumber: Int) -> String {
    jsonString([
      "type": "response.completed",
      "response": responseObject(id: responseID, status: "completed"),
      "sequence_number": sequenceNumber,
    ])
  }

  private static func textDeltaEvent(
    itemID: String,
    outputIndex: Int,
    contentIndex: Int,
    delta: String,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.output_text.delta",
      "item_id": itemID,
      "output_index": outputIndex,
      "content_index": contentIndex,
      "delta": delta,
      "sequence_number": sequenceNumber,
      "logprobs": [],
    ])
  }

  private static func textDoneEvent(
    itemID: String,
    outputIndex: Int,
    contentIndex: Int,
    text: String,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.output_text.done",
      "item_id": itemID,
      "output_index": outputIndex,
      "content_index": contentIndex,
      "text": text,
      "sequence_number": sequenceNumber,
      "logprobs": [],
    ])
  }

  private static func functionCallOutputItemDoneEvent(
    itemID: String,
    callID: String,
    name: String,
    arguments: String,
    outputIndex: Int,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.output_item.done",
      "output_index": outputIndex,
      "sequence_number": sequenceNumber,
      "item": [
        "type": "function_call",
        "id": itemID,
        "call_id": callID,
        "name": name,
        "arguments": arguments,
        "status": "completed",
      ],
    ])
  }

  private static func imagePartialEvent(
    itemID: String,
    outputIndex: Int,
    partialImageIndex: Int,
    partialImageBase64: String,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.image_generation_call.partial_image",
      "output_index": outputIndex,
      "item_id": itemID,
      "sequence_number": sequenceNumber,
      "partial_image_index": partialImageIndex,
      "partial_image_b64": partialImageBase64,
    ])
  }

  private static func imageOutputItemDoneEvent(
    itemID: String,
    outputIndex: Int,
    status: String,
    resultBase64: String,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.output_item.done",
      "output_index": outputIndex,
      "sequence_number": sequenceNumber,
      "item": [
        "type": "image_generation_call",
        "id": itemID,
        "status": status,
        "result": resultBase64,
      ],
    ])
  }

  private static func responseObject(id: String, status: String) -> [String: Any] {
    [
      "id": id,
      "object": "response",
      "created_at": 1_771_443_518,
      "status": status,
      "model": "gpt-5.2",
      "output": [],
      "parallel_tool_calls": true,
      "tools": [],
    ]
  }

  private static func jsonString(_ object: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
  }
}

private struct StreamQueueTransport: ClientTransport {
  private let state: StreamQueueState

  init(payloads: [String]) {
    self.state = StreamQueueState(payloads: payloads)
  }

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    guard operationID == "createResponse" else {
      throw StreamQueueStateError.unexpectedOperation(operationID)
    }

    let requestBody: String
    if let body {
      let data = try await Data(collecting: body, upTo: .max)
      requestBody = String(decoding: data, as: UTF8.self)
    } else {
      requestBody = ""
    }

    let payload = try await state.consumeNextPayload(requestBody: requestBody)

    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "text/event-stream"
    return (response, HTTPBody(payload))
  }

  func requestBodies() async -> [String] {
    await state.requestBodies()
  }
}

private actor StreamQueueState {
  private var payloads: [String]
  private var capturedRequestBodies: [String] = []

  init(payloads: [String]) {
    self.payloads = payloads
  }

  func consumeNextPayload(requestBody: String) throws -> String {
    capturedRequestBodies.append(requestBody)
    guard !payloads.isEmpty else {
      throw StreamQueueStateError.missingQueuedResponse
    }
    return payloads.removeFirst()
  }

  func requestBodies() -> [String] {
    capturedRequestBodies
  }
}

private enum StreamQueueStateError: Error {
  case missingQueuedResponse
  case unexpectedOperation(String)
}

private struct WeatherEchoTool: Toolable {
  typealias Input = String

  let name = "get_weather"
  let description: String? = "Returns a deterministic weather string"
  let strict = true
  let prefix: String

  var parameters: some JSONSchemaComponent<Input> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString()
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters: Input) async throws -> String {
    "\(prefix):\(parameters)"
  }
}

private actor AttemptCounter {
  private var attempts = 0

  func next() -> Int {
    attempts += 1
    return attempts
  }

  func value() -> Int {
    attempts
  }
}

private struct ToolExecutionFailure: Error {
  let message: String
}

private struct AlwaysFailWeatherTool: Toolable {
  typealias Input = String

  let name = "always_fail_weather"
  let description: String? = "Always throws to test error policies"
  let strict = true

  var parameters: some JSONSchemaComponent<Input> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString()
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters _: Input) async throws -> String {
    throw ToolExecutionFailure(message: "always fail")
  }
}

private struct FlakyWeatherTool: Toolable {
  typealias Input = String

  let name = "flaky_weather"
  let description: String? = "Fails first N attempts before succeeding"
  let strict = true

  let attempts: AttemptCounter
  let failUntilAttempt: Int

  var parameters: some JSONSchemaComponent<Input> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString()
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters: Input) async throws -> String {
    let attempt = await attempts.next()
    if attempt <= failUntilAttempt {
      throw ToolExecutionFailure(message: "flaky fail at attempt \(attempt)")
    }
    return "flaky-success:\(parameters):attempt_\(attempt)"
  }
}
