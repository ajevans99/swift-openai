@testable import OpenAICore
import Testing

@Suite("Streaming SSE Parser")
struct StreamingSSEParserTests {
  @Test("Parses event split across arbitrary chunks")
  func parsesSplitChunks() {
    var parser = StreamingSSEParser()
    var events: [StreamingSSEEvent] = []

    let chunks = [
      ArraySlice("event: response.created\nda".utf8),
      ArraySlice("ta: {\"type\":\"response.created\"".utf8),
      ArraySlice("}\n\n".utf8),
    ]

    for chunk in chunks {
      events.append(contentsOf: parser.consume(chunk))
    }

    #expect(events.count == 1)
    #expect(events[0].event == "response.created")
    #expect(events[0].data == "{\"type\":\"response.created\"}")
  }

  @Test("Parses CRLF and multiline data")
  func parsesCRLFAndMultilineData() {
    var parser = StreamingSSEParser()

    let payload = "event: sample\r\ndata: first line\r\ndata: second line\r\n\r\n"
    let events = parser.consume(ArraySlice(payload.utf8))

    #expect(events.count == 1)
    #expect(events[0].event == "sample")
    #expect(events[0].data == "first line\nsecond line")
  }

  @Test("Handles large data line split into many chunks")
  func handlesLargeDataLine() {
    var parser = StreamingSSEParser()

    let large = String(repeating: "a", count: 400_000)
    let event = "event: response.image_generation_call.partial_image\ndata: {\"type\":\"response.image_generation_call.partial_image\",\"partial_image_b64\":\"\(large)\"}\n\n"
    let bytes = Array(event.utf8)

    var events: [StreamingSSEEvent] = []
    var index = 0
    while index < bytes.count {
      let next = min(index + 2048, bytes.count)
      events.append(contentsOf: parser.consume(ArraySlice(bytes[index..<next])))
      index = next
    }

    #expect(events.count == 1)
    #expect(events[0].event == "response.image_generation_call.partial_image")
    #expect(events[0].data?.contains(large) == true)
  }
}
