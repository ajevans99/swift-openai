import Foundation
import Testing

import OpenAICore
import OpenAIFoundation

@Suite("Streaming Response Decoding")
struct StreamingResponseDecodingTests {
  @Test("Decodes response.created and response.in_progress with image_generation tools")
  func decodesCreatedAndInProgressEvents() throws {
    let createdPayload = #"""
    {
      "type": "response.created",
      "response": {
        "id": "resp_test_created",
        "object": "response",
        "created_at": 1771443518,
        "status": "in_progress",
        "model": "gpt-4o-2024-08-06",
        "output": [],
        "parallel_tool_calls": true,
        "tools": [
          {
            "type": "image_generation"
          }
        ]
      },
      "sequence_number": 0
    }
    """#

    let inProgressPayload = #"""
    {
      "type": "response.in_progress",
      "response": {
        "id": "resp_test_in_progress",
        "object": "response",
        "created_at": 1771443518,
        "status": "in_progress",
        "model": "gpt-4o-2024-08-06",
        "output": [],
        "parallel_tool_calls": true,
        "tools": [
          {
            "type": "image_generation"
          }
        ]
      },
      "sequence_number": 1
    }
    """#

    let createdEvent = try Self.decodeResponseStreamEvent(from: createdPayload)
    let inProgressEvent = try Self.decodeResponseStreamEvent(from: inProgressPayload)

    let mappedCreated = StreamingResponse(openAPI: createdEvent)
    let mappedInProgress = StreamingResponse(openAPI: inProgressEvent)

    guard let mappedCreated else {
      Issue.record("Expected response.created to map into StreamingResponse")
      return
    }
    guard let mappedInProgress else {
      Issue.record("Expected response.in_progress to map into StreamingResponse")
      return
    }

    switch mappedCreated {
    case .created(let response):
      #expect(response.id == "resp_test_created")
    default:
      Issue.record("Expected .created, got \(mappedCreated.value)")
    }

    switch mappedInProgress {
    case .inProgress(let response):
      #expect(response.id == "resp_test_in_progress")
    default:
      Issue.record("Expected .inProgress, got \(mappedInProgress.value)")
    }
  }

  @Test("Tool discriminator accepts API wire type values")
  func toolDiscriminatorAcceptsWireValues() throws {
    let toolPayloads: [String] = [
      #"{"type":"function","name":"weather_lookup"}"#,
      #"{"type":"file_search","vector_store_ids":["vs_123"]}"#,
      #"{"type":"computer_use_preview","environment":"mac","display_width":1280,"display_height":720}"#,
      #"{"type":"web_search"}"#,
      #"{"type":"web_search_2025_08_26"}"#,
      #"{"type":"mcp","server_label":"docs","server_url":"https://example.com/mcp"}"#,
      #"{"type":"code_interpreter","container":"container_123"}"#,
      #"{"type":"image_generation"}"#,
      #"{"type":"local_shell"}"#,
      #"{"type":"shell"}"#,
      #"{"type":"custom","name":"parse_document"}"#,
      #"{"type":"web_search_preview"}"#,
      #"{"type":"web_search_preview_2025_03_11"}"#,
      #"{"type":"apply_patch"}"#,
    ]

    let decoder = JSONDecoder()
    for payload in toolPayloads {
      let data = Data(payload.utf8)
      _ = try decoder.decode(Components.Schemas.Tool.self, from: data)
    }
  }

  @Test("Image generation output item preserves final base64 result")
  func imageGenerationOutputItemPreservesResult() throws {
    let payload = #"""
    {
      "type": "image_generation_call",
      "id": "ig_test_123",
      "status": "completed",
      "result": "ZmFrZV9pbWFnZV9iYXNlNjQ="
    }
    """#

    let data = Data(payload.utf8)
    let item = try JSONDecoder().decode(Components.Schemas.OutputItem.self, from: data)

    guard let imageCall = Self.extractImageGenToolCall(from: item) else {
      Issue.record("Expected output item to decode as ImageGenToolCall")
      return
    }

    #expect(imageCall.id == "ig_test_123")
    #expect(imageCall.result == "ZmFrZV9pbWFnZV9iYXNlNjQ=")
  }

  @Test("Completed responses drop raw reasoning output items")
  func completedResponsesDropRawReasoningOutputItems() throws {
    let payload = #"""
    {
      "id": "resp_reasoning_privacy",
      "object": "response",
      "created_at": 1771443518,
      "status": "completed",
      "model": "gpt-4o-2024-08-06",
      "output": [
        {
          "type": "reasoning",
          "id": "rs_privacy",
          "summary": [
            {
              "type": "summary_text",
              "text": "safe provider summary"
            }
          ],
          "content": [
            {
              "type": "reasoning_text",
              "text": "provider-hidden-reasoning"
            }
          ],
          "status": "completed"
        }
      ],
      "parallel_tool_calls": true,
      "tools": []
    }
    """#

    let openAPIResponse = try JSONDecoder().decode(
      Components.Schemas.Response.self,
      from: Data(payload.utf8)
    )

    let response = Response(openAPI: openAPIResponse)

    #expect(response.output.isEmpty)
    #expect(response.outputText.isEmpty)
  }

  @Test("OutputItem mapping drops raw reasoning items")
  func outputItemMappingDropsRawReasoningItems() {
    let rawReasoningItem = Components.Schemas.OutputItem(
      value6: Components.Schemas.ReasoningItem(
        _type: .reasoning,
        id: "rs_privacy",
        summary: [
          Components.Schemas.SummaryTextContent(
            _type: .summaryText,
            text: "safe provider summary"
          )
        ],
        content: [
          Components.Schemas.ReasoningTextContent(
            _type: .reasoningText,
            text: "provider-hidden-reasoning"
          )
        ],
        status: .completed
      )
    )

    if OpenAICore.OutputItem(rawReasoningItem) != nil {
      Issue.record("Expected raw reasoning output item to be dropped")
    }
  }

  @Test("Streaming drops raw reasoning text events")
  func streamingDropsRawReasoningTextEvents() {
    let rawDeltaEvent = Components.Schemas.ResponseStreamEvent(
      value29: Components.Schemas.ResponseReasoningTextDeltaEvent(
        _type: .response_reasoningText_delta,
        itemId: "rs_privacy",
        outputIndex: 0,
        contentIndex: 0,
        delta: "provider-hidden-reasoning-delta",
        sequenceNumber: 1
      )
    )
    let rawDoneEvent = Components.Schemas.ResponseStreamEvent(
      value30: Components.Schemas.ResponseReasoningTextDoneEvent(
        _type: .response_reasoningText_done,
        itemId: "rs_privacy",
        outputIndex: 0,
        contentIndex: 0,
        text: "provider-hidden-reasoning-done",
        sequenceNumber: 2
      )
    )

    if StreamingResponse(openAPI: rawDeltaEvent) != nil {
      Issue.record("Expected raw reasoning text delta event to be dropped")
    }
    if StreamingResponse(openAPI: rawDoneEvent) != nil {
      Issue.record("Expected raw reasoning text done event to be dropped")
    }
  }

  @Test("Streaming preserves reasoning summary text events")
  func streamingPreservesReasoningSummaryTextEvents() {
    let summaryDeltaEvent = Components.Schemas.ResponseStreamEvent(
      value27: Components.Schemas.ResponseReasoningSummaryTextDeltaEvent(
        _type: .response_reasoningSummaryText_delta,
        itemId: "rs_privacy",
        outputIndex: 0,
        summaryIndex: 0,
        delta: "safe summary delta",
        sequenceNumber: 3
      )
    )
    let summaryDoneEvent = Components.Schemas.ResponseStreamEvent(
      value28: Components.Schemas.ResponseReasoningSummaryTextDoneEvent(
        _type: .response_reasoningSummaryText_done,
        itemId: "rs_privacy",
        outputIndex: 0,
        summaryIndex: 0,
        text: "safe summary done",
        sequenceNumber: 4
      )
    )

    guard let mappedDelta = StreamingResponse(openAPI: summaryDeltaEvent) else {
      Issue.record("Expected reasoning summary text delta event to be surfaced")
      return
    }
    guard let mappedDone = StreamingResponse(openAPI: summaryDoneEvent) else {
      Issue.record("Expected reasoning summary text done event to be surfaced")
      return
    }

    switch mappedDelta {
    case .reasoningSummaryText(.delta(let delta, let summaryIndex, let itemId, let outputIndex)):
      #expect(delta == "safe summary delta")
      #expect(summaryIndex == 0)
      #expect(itemId == "rs_privacy")
      #expect(outputIndex == 0)
    default:
      Issue.record("Expected reasoning summary text delta event")
    }

    switch mappedDone {
    case .reasoningSummaryText(.done(let text, let summaryIndex, let itemId, let outputIndex)):
      #expect(text == "safe summary done")
      #expect(summaryIndex == 0)
      #expect(itemId == "rs_privacy")
      #expect(outputIndex == 0)
    default:
      Issue.record("Expected reasoning summary text done event")
    }
  }

  @Test("StreamingResponse maps all generated ResponseStreamEvent slots")
  func streamingResponseCoversGeneratedSlots() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let typesFile = packageRoot.appendingPathComponent("Sources/OpenAIFoundation/Generated/Types.swift")
    let streamingFile = packageRoot.appendingPathComponent("Sources/OpenAICore/Responses/StreamingResponse.swift")

    let typesSource = try String(contentsOf: typesFile, encoding: .utf8)
    let streamingSource = try String(contentsOf: streamingFile, encoding: .utf8)

    guard
      let responseStructStart = typesSource.range(of: "public struct ResponseStreamEvent"),
      let responseStructEnd = typesSource.range(
        of: "/// Creates a new `ResponseStreamEvent`",
        range: responseStructStart.upperBound..<typesSource.endIndex
      )
    else {
      Issue.record("Could not locate ResponseStreamEvent declaration in generated types")
      return
    }

    let responseStructSnippet = String(typesSource[responseStructStart.lowerBound..<responseStructEnd.lowerBound])
    let generatedSlots = try Self.captureIntegers(
      pattern: #"public var value(\d+):"#,
      in: responseStructSnippet
    )
    let mappedSlots = try Self.captureIntegers(
      pattern: #"openAPI\.value(\d+)"#,
      in: streamingSource
    )

    #expect(generatedSlots.isEmpty == false)
    #expect(generatedSlots == mappedSlots)
  }

  private static func decodeResponseStreamEvent(from payload: String) throws -> Components.Schemas.ResponseStreamEvent {
    let data = Data(payload.utf8)
    return try JSONDecoder().decode(Components.Schemas.ResponseStreamEvent.self, from: data)
  }

  private static func extractImageGenToolCall(
    from item: Components.Schemas.OutputItem
  ) -> Components.Schemas.ImageGenToolCall? {
    for child in Mirror(reflecting: item).children {
      let optionalMirror = Mirror(reflecting: child.value)
      guard optionalMirror.displayStyle == .optional else { continue }
      guard let wrappedValue = optionalMirror.children.first?.value else { continue }
      if let imageCall = wrappedValue as? Components.Schemas.ImageGenToolCall {
        return imageCall
      }
    }
    return nil
  }

  private static func captureIntegers(pattern: String, in source: String) throws -> Set<Int> {
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    let matches = regex.matches(in: source, range: range)

    var integers = Set<Int>()
    integers.reserveCapacity(matches.count)

    for match in matches {
      guard
        let captureRange = Range(match.range(at: 1), in: source),
        let integer = Int(source[captureRange])
      else { continue }
      integers.insert(integer)
    }

    return integers
  }
}
