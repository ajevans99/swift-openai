import CustomDump
import Foundation
import HTTPTypes
import JSONSchema
import JSONSchemaBuilder
import Logging
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
    #expect(requestBodies[0].contains(#""name" : "get_weather""#))
    #expect(requestBodies[1].contains(#""type" : "function_call_output""#))
    #expect(requestBodies[1].contains(#""call_id" : "call_weather_1""#))
    #expect(requestBodies[1].contains(#""previous_response_id" : "resp_tool_1""#))
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

  @Test("Text plugin preserves every delta when consumer starts after production")
  func textPluginIsLosslessByDefault() async throws {
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
      streamOptions: .init(rawEvents: .disabled),
      plugins: TextPlugin()
    )
    let textChannel = handle.pluginEvents

    let events = try await Self.collect(textChannel.events)
    let deltas = events.compactMap { event -> String? in
      guard case .delta(let value) = event else { return nil }
      return value
    }
    #expect(deltas == (0..<400).map { "chunk_\($0)" })
    #expect(events.last == .completed("done"))
  }

  @Test("Bounded plugin channels fail explicitly instead of truncating")
  func boundedPluginOverflowFailsExplicitly() async throws {
    guard #available(macOS 15.0, *) else { return }
    let deltaEvents = (0..<10).map { index in
      Self.textDeltaEvent(
        itemID: "msg_bounded",
        outputIndex: 0,
        contentIndex: 0,
        delta: "chunk_\(index)",
        sequenceNumber: index + 1
      )
    }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload(
          [Self.createdEvent(responseID: "resp_bounded", sequenceNumber: 0)]
            + deltaEvents
            + [Self.completedEvent(responseID: "resp_bounded", sequenceNumber: 20)]
        )
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let handle = try await session.stream(
      "Generate bounded chunks",
      streamOptions: .init(rawEvents: .disabled, pluginEvents: .bounded(2)),
      plugins: TextPlugin()
    )
    try await Task.sleep(for: .milliseconds(20))

    do {
      _ = try await Self.collect(handle.pluginEvents.events)
      Issue.record("Expected bounded channel overflow")
    } catch let error as ResponseSessionError {
      guard case .bufferOverflow(_, let capacity) = error else {
        Issue.record("Expected bufferOverflow, got \(error)")
        return
      }
      #expect(capacity == 2)
    }
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

  @Test("ResponseSession stream forwards reasoning options")
  func responseSessionStreamForwardsReasoningOptions() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.completedEvent(responseID: "resp_123", sequenceNumber: 0)
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)

    let rawStream = try await session.streamRaw(
      items: [
        .inputMessage(
          InputMessage(role: .user, content: [.text(.init(text: "Hello"))])
        )
      ],
      requestOptions: .init(reasoning: Reasoning(effort: .medium, summary: .auto))
    )

    _ = try await Self.collectRawValues(rawStream)

    let requestBodies = await transport.requestBodies()
    #expect(requestBodies.count == 1)
    let json = requestBodies[0]
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "\n", with: "")
    #expect(json.contains(#""reasoning""#))
    #expect(json.contains(#""effort":"medium""#))
    #expect(json.contains(#""summary":"auto""#))
  }

  @Test("Durable instructions are resent across streaming tool rounds")
  func durableInstructionsAcrossStreamingToolRounds() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_instruction_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_instruction",
            callID: "call_instruction",
            name: "get_weather",
            arguments: #"{"location":"Boston"}"#,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_instruction_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_instruction_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_instruction_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(
      transport: transport,
      instructions: "Always coach with concise next steps."
    )
    let handle = try await session.stream(
      "Use the tool",
      streamOptions: .init(rawEvents: .disabled),
      plugins: ToolOrchestratorPlugin(tools: [WeatherEchoTool(prefix: "durable")])
    )

    _ = try await Self.collect(handle.pluginEvents.events)
    let requestBodies = await transport.requestBodies()
    #expect(requestBodies.count == 2)
    #expect(
      requestBodies.allSatisfy {
        $0.contains(#""instructions" : "Always coach with concise next steps.""#)
      })
  }

  @Test("Durable instructions are resent across non-streaming tool rounds")
  func durableInstructionsAcrossNonStreamingToolRounds() async throws {
    let transport = NonStreamingQueueTransport(
      payloads: [
        Self.jsonString(
          Self.responseObject(
            id: "resp_nonstream_1",
            status: "completed",
            output: [
              [
                "type": "function_call",
                "id": "fc_nonstream",
                "call_id": "call_nonstream",
                "name": "get_weather",
                "arguments": #"{"location":"Portland"}"#,
                "status": "completed",
              ]
            ]
          )
        ),
        Self.jsonString(
          Self.responseObject(
            id: "resp_nonstream_2",
            status: "completed",
            output: [
              [
                "type": "message",
                "id": "msg_nonstream",
                "status": "completed",
                "role": "assistant",
                "content": [
                  [
                    "type": "output_text",
                    "text": "Coaching complete.",
                    "annotations": [],
                    "logprobs": [],
                  ]
                ],
              ]
            ]
          )
        ),
      ]
    )
    let session = try Self.makeSession(
      transport: transport,
      instructions: "Keep the coaching plan durable."
    )
    await session.register(tool: WeatherEchoTool(prefix: "nonstream"))

    let text = try await session.send(
      inputItems: [
        .easyInputMessage(.init(role: .user, content: .text("Coach me")))
      ]
    )

    #expect(text == "Coaching complete.")
    let requestBodies = await transport.requestBodies()
    #expect(requestBodies.count == 2)
    #expect(
      requestBodies.allSatisfy {
        $0.contains(#""instructions" : "Keep the coaching plan durable.""#)
      })
    #expect(requestBodies[1].contains(#""previous_response_id" : "resp_nonstream_1""#))
  }

  @Test("Typed input history accepts assistant messages")
  func typedAssistantHistory() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_history", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_history", sequenceNumber: 1),
        ])
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let stream = try await session.streamRaw(
      inputItems: [
        .easyInputMessage(.init(role: .assistant, content: .text("Earlier answer"))),
        .easyInputMessage(.init(role: .user, content: .text("Follow-up question"))),
      ]
    )

    _ = try await Self.collectRawValues(stream)
    let requestBody = try #require(await transport.requestBodies().first)
    #expect(requestBody.contains(#""role" : "assistant""#))
    #expect(requestBody.contains(#""content" : "Earlier answer""#))
    #expect(requestBody.contains(#""role" : "user""#))
  }

  @Test("Lifecycle plugin emits response IDs for every recursive round")
  func lifecyclePluginAcrossToolRounds() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_lifecycle_1", sequenceNumber: 0),
          Self.functionCallOutputItemDoneEvent(
            itemID: "fc_lifecycle",
            callID: "call_lifecycle",
            name: "get_weather",
            arguments: #"{"location":"Miami"}"#,
            outputIndex: 0,
            sequenceNumber: 1
          ),
          Self.completedEvent(responseID: "resp_lifecycle_1", sequenceNumber: 2),
        ]),
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_lifecycle_2", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_lifecycle_2", sequenceNumber: 1),
        ]),
      ]
    )
    let session = try Self.makeSession(transport: transport)
    let handle = try await session.stream(
      "Track lifecycle",
      streamOptions: .init(rawEvents: .disabled),
      plugins:
        ResponseLifecyclePlugin(),
        ToolOrchestratorPlugin(tools: [WeatherEchoTool(prefix: "lifecycle")])
    )
    let (lifecycleChannel, toolChannel) = handle.pluginEvents

    let lifecycleEvents = try await Self.collect(lifecycleChannel.events)
    _ = try await Self.collect(toolChannel.events)
    #expect(lifecycleEvents.map(\.responseID) == [
      "resp_lifecycle_1",
      "resp_lifecycle_1",
      "resp_lifecycle_2",
      "resp_lifecycle_2",
    ])
    #expect(lifecycleEvents.map(\.isTerminal) == [false, true, false, true])
  }

  @Test("Lifecycle plugin distinguishes failed and incomplete terminals")
  func lifecyclePluginTerminalStates() async throws {
    guard #available(macOS 15.0, *) else { return }
    let failedTransport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_failed", sequenceNumber: 0),
          Self.failedEvent(responseID: "resp_failed", sequenceNumber: 1),
        ])
      ]
    )
    let failedSession = try Self.makeSession(transport: failedTransport)
    let failedHandle = try await failedSession.stream(
      "Fail",
      streamOptions: .init(rawEvents: .disabled),
      plugins: ResponseLifecyclePlugin()
    )
    let failedEvents = try await Self.collect(failedHandle.pluginEvents.events)
    guard case .failed(let failedResponse) = try #require(failedEvents.last) else {
      Issue.record("Expected failed lifecycle event")
      return
    }
    #expect(failedResponse.id == "resp_failed")

    let incompleteTransport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_incomplete", sequenceNumber: 0),
          Self.incompleteEvent(responseID: "resp_incomplete", sequenceNumber: 1),
        ])
      ]
    )
    let incompleteSession = try Self.makeSession(transport: incompleteTransport)
    let incompleteHandle = try await incompleteSession.stream(
      "Incomplete",
      streamOptions: .init(rawEvents: .disabled),
      plugins: ResponseLifecyclePlugin()
    )
    let incompleteEvents = try await Self.collect(incompleteHandle.pluginEvents.events)
    guard case .incomplete(let incompleteResponse) = try #require(incompleteEvents.last) else {
      Issue.record("Expected incomplete lifecycle event")
      return
    }
    #expect(incompleteResponse.id == "resp_incomplete")
  }

  @Test("OpenAI client forwards an injected server URL")
  func injectedServerURL() async throws {
    guard #available(macOS 15.0, *) else { return }
    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.createdEvent(responseID: "resp_url", sequenceNumber: 0),
          Self.completedEvent(responseID: "resp_url", sequenceNumber: 1),
        ])
      ]
    )
    let serverURL = try #require(URL(string: "http://127.0.0.1:8787/v1"))
    let client = try OpenAI(
      transport: transport,
      apiKey: "test-key",
      serverURL: serverURL
    )
    let stream = try await client.streamCreateResponse(
      input: .text("Hello"),
      model: .custom("gpt-5.2")
    )

    for try await _ in stream {}
    #expect(await transport.baseURLs() == [serverURL])
  }

  @Test("Explicit cancellation terminates the provider HTTP body")
  func explicitCancellationTerminatesProviderBody() async throws {
    guard #available(macOS 15.0, *) else { return }
    let probe = CancellationProbe()
    let transport = CancellationAwareTransport(probe: probe)
    let session = try Self.makeSession(transport: transport)
    let handle = try await session.stream(
      "Keep streaming",
      streamOptions: .init(rawEvents: .disabled),
      plugins: ResponseLifecyclePlugin()
    )
    var iterator = handle.pluginEvents.events.makeAsyncIterator()
    let first = try await iterator.next()
    #expect(first?.responseID == "resp_cancel")

    handle.cancel()
    do {
      _ = try await iterator.next()
      Issue.record("Expected plugin channel cancellation")
    } catch is CancellationError {
      // Expected.
    }
    try await Task.sleep(for: .milliseconds(20))
    #expect(await probe.wasCancelled())
  }

  @Test("Raw reasoning SSE decode failures do not log hidden payload text")
  func rawReasoningSSEDecodeFailuresDoNotLogHiddenPayloadText() async throws {
    guard #available(macOS 15.0, *) else { return }

    let hiddenDelta = "provider-hidden-reasoning-delta"
    let hiddenDone = "provider-hidden-reasoning-done"
    let logCapture = CapturingLogStorage()
    var logger = Logger(label: "swift-openai-test") { _ in
      CapturingLogHandler(storage: logCapture)
    }
    logger.logLevel = .debug

    let transport = StreamQueueTransport(
      payloads: [
        Self.ssePayload([
          Self.malformedReasoningTextDeltaEvent(delta: hiddenDelta, sequenceNumber: 0),
          Self.malformedReasoningTextDoneEvent(text: hiddenDone, sequenceNumber: 1),
          Self.reasoningSummaryTextDeltaEvent(delta: "safe summary", sequenceNumber: 2),
          Self.completedEvent(responseID: "resp_reasoning_privacy", sequenceNumber: 3),
        ])
      ]
    )
    let client = try OpenAI(transport: transport, apiKey: "test-key", logger: logger)
    let stream = try await client.streamCreateResponse(input: .text("Hello"), model: .custom("gpt-5.2"))

    var values: [String] = []
    var summaryDeltas: [String] = []
    for try await event in stream {
      values.append(event.value)
      if case .reasoningSummaryText(.delta(let delta, _, _, _)) = event {
        summaryDeltas.append(delta)
      }
    }

    let logs = logCapture.messages.joined(separator: "\n")
    #expect(values.contains("response.reasoning_summary_text.delta"))
    #expect(summaryDeltas.contains("safe summary"))
    #expect(!values.contains("response.reasoning_text.delta"))
    #expect(!values.contains("response.reasoning_text.done"))
    #expect(!logs.contains(hiddenDelta))
    #expect(!logs.contains(hiddenDone))
  }
}

extension ResponseSessionStreamingTests {
  private static func makeSession(
    transport: some ClientTransport,
    instructions: String? = nil,
    errorPolicy: ToolErrorPolicy = .failFast
  ) throws -> ResponseSession {
    let client = try OpenAI(transport: transport, apiKey: "test-key")
    return ResponseSession(
      client: client,
      model: .custom("gpt-5.2"),
      instructions: instructions,
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

  fileprivate static func ssePayload(_ events: [String]) -> String {
    events.map { "data: \($0)\n\n" }.joined()
  }

  fileprivate static func createdEvent(responseID: String, sequenceNumber: Int) -> String {
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

  private static func failedEvent(responseID: String, sequenceNumber: Int) -> String {
    jsonString([
      "type": "response.failed",
      "response": responseObject(id: responseID, status: "failed"),
      "sequence_number": sequenceNumber,
    ])
  }

  private static func incompleteEvent(responseID: String, sequenceNumber: Int) -> String {
    jsonString([
      "type": "response.incomplete",
      "response": responseObject(id: responseID, status: "incomplete"),
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

  private static func malformedReasoningTextDeltaEvent(
    delta: String,
    sequenceNumber: Int
  ) -> String {
    #"{"type":"response.reasoning_text.delta","delta":"\#(delta)","sequence_number":\#(sequenceNumber)"#
  }

  private static func malformedReasoningTextDoneEvent(
    text: String,
    sequenceNumber: Int
  ) -> String {
    #"{"type":"response.reasoning_text.done","text":"\#(text)","sequence_number":\#(sequenceNumber)"#
  }

  private static func reasoningSummaryTextDeltaEvent(
    delta: String,
    sequenceNumber: Int
  ) -> String {
    jsonString([
      "type": "response.reasoning_summary_text.delta",
      "item_id": "rs_privacy",
      "output_index": 0,
      "summary_index": 0,
      "delta": delta,
      "sequence_number": sequenceNumber,
    ])
  }

  fileprivate static func responseObject(
    id: String,
    status: String,
    output: [[String: Any]] = []
  ) -> [String: Any] {
    [
      "id": id,
      "object": "response",
      "created_at": 1_771_443_518,
      "status": status,
      "model": "gpt-5.2",
      "output": output,
      "parallel_tool_calls": true,
      "tools": [],
    ]
  }

  fileprivate static func jsonString(_ object: [String: Any]) -> String {
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

    let payload = try await state.consumeNextPayload(
      requestBody: requestBody,
      baseURL: baseURL
    )

    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "text/event-stream"
    return (response, HTTPBody(payload))
  }

  func requestBodies() async -> [String] {
    await state.requestBodies()
  }

  func baseURLs() async -> [URL] {
    await state.baseURLs()
  }
}

private actor StreamQueueState {
  private var payloads: [String]
  private var capturedRequestBodies: [String] = []
  private var capturedBaseURLs: [URL] = []

  init(payloads: [String]) {
    self.payloads = payloads
  }

  func consumeNextPayload(requestBody: String, baseURL: URL) throws -> String {
    capturedRequestBodies.append(requestBody)
    capturedBaseURLs.append(baseURL)
    guard !payloads.isEmpty else {
      throw StreamQueueStateError.missingQueuedResponse
    }
    return payloads.removeFirst()
  }

  func requestBodies() -> [String] {
    capturedRequestBodies
  }

  func baseURLs() -> [URL] {
    capturedBaseURLs
  }
}

private enum StreamQueueStateError: Error {
  case missingQueuedResponse
  case unexpectedOperation(String)
}

private struct NonStreamingQueueTransport: ClientTransport {
  private let state: NonStreamingQueueState

  init(payloads: [String]) {
    state = NonStreamingQueueState(payloads: payloads)
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
    response.headerFields[.contentType] = "application/json"
    return (response, HTTPBody(payload))
  }

  func requestBodies() async -> [String] {
    await state.requestBodies()
  }
}

private actor NonStreamingQueueState {
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

private struct CancellationAwareTransport: ClientTransport {
  let probe: CancellationProbe

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let stream = AsyncThrowingStream<String, Error> { continuation in
      continuation.yield(
        ResponseSessionStreamingTests.ssePayload([
          ResponseSessionStreamingTests.createdEvent(
            responseID: "resp_cancel",
            sequenceNumber: 0
          )
        ])
      )
      continuation.onTermination = { _ in
        Task {
          await probe.recordCancellation()
        }
      }
    }
    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "text/event-stream"
    return (
      response,
      HTTPBody(stream, length: .unknown)
    )
  }
}

private actor CancellationProbe {
  private var cancelled = false

  func recordCancellation() {
    cancelled = true
  }

  func wasCancelled() -> Bool {
    cancelled
  }
}

private final class CapturingLogStorage: @unchecked Sendable {
  private let lock = NSLock()
  private var capturedMessages: [String] = []

  var messages: [String] {
    lock.withLock { capturedMessages }
  }

  func append(_ message: String) {
    lock.withLock {
      capturedMessages.append(message)
    }
  }
}

private struct CapturingLogHandler: LogHandler {
  let storage: CapturingLogStorage
  var metadata: Logger.Metadata = [:]
  var logLevel: Logger.Level = .trace

  subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
    get { metadata[metadataKey] }
    set { metadata[metadataKey] = newValue }
  }

  func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    storage.append(message.description)
  }
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
