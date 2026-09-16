import CustomDump
import Foundation
import HTTPTypes
import OpenAICore
import OpenAPIRuntime
import Testing

@Suite("Legacy Image Edit Transport")
struct ImageEditTransportTests {
  @Test("Image editing retains multipart upload and injected transport")
  func multipartImageEdit() async throws {
    let transport = ImageEditRecordingTransport()
    let baseURL = try #require(URL(string: "https://example.invalid/v1"))
    let client = try OpenAI(
      transport: transport,
      apiKey: "recording-only",
      serverURL: baseURL
    )
    let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
    let response = try await client.editImage(
      image: .single(.init(filename: "input.png", content: imageBytes)),
      prompt: "Make the background blue",
      model: .gptImage2
    )

    let captured = try #require(await transport.captured)
    expectNoDifference(captured.request.method, .post)
    expectNoDifference(captured.request.path, "/images/edits")
    expectNoDifference(captured.request.headerFields[.authorization], "Bearer recording-only")
    expectNoDifference(captured.baseURL, baseURL)
    expectNoDifference(captured.operationID, "createImageEdit")
    #expect(captured.request.headerFields[.contentType]?.hasPrefix("multipart/form-data;") == true)
    #expect(captured.body.range(of: imageBytes) != nil)
    let wire = String(decoding: captured.body, as: UTF8.self)
    #expect(wire.contains("name=\"image\""))
    #expect(wire.contains("filename=\"input.png\""))
    #expect(wire.contains("name=\"prompt\""))
    #expect(wire.contains("Make the background blue"))
    #expect(wire.contains("gpt-image-2"))
    expectNoDifference(response.created, 123)
    expectNoDifference(response.data.first?.b64Json, "aW1hZ2U=")
  }
}

private actor ImageEditRecordingTransport: ClientTransport {
  struct Captured: Sendable {
    let request: HTTPRequest
    let body: Data
    let baseURL: URL
    let operationID: String
  }

  private(set) var captured: Captured?

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let body = try #require(body)
    captured = Captured(
      request: request,
      body: try await Data(collecting: body, upTo: 10_000),
      baseURL: baseURL,
      operationID: operationID
    )
    var response = HTTPResponse(status: .ok)
    response.headerFields[.contentType] = "application/json"
    return (response, HTTPBody(#"{"created":123,"data":[{"b64_json":"aW1hZ2U="}]}"#))
  }
}
