import Foundation
import OpenAICore
import OpenAIFoundation
import Testing

@Suite("Response Snapshot Tests")
struct ResponseSnapshotTests {
  struct SnapshotCase: Sendable {
    let name: String
    let fixtureName: String
    let model: String
    let input: String
    let expectedToken: String
  }

  enum SnapshotTestError: Error {
    case missingAPIKey
    case missingFixture(URL)
    case invalidHTTPStatus(Int, String)
    case missingImagePayload
  }

  static let snapshotCases: [SnapshotCase] = [
    .init(
      name: "hello_world_gpt5_5",
      // The local replay fixture only proves response decoding; the live smoke below
      // verifies GPT-5.5 against the API.
      fixtureName: "hello_world_gpt5_2",
      model: "gpt-5.5",
      input: "Reply with EXACTLY this token and nothing else: SNAPSHOT_OK",
      expectedToken: "SNAPSHOT_OK"
    )
  ]

  static var fixturesDirectoryURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/Responses", isDirectory: true)
  }

  static var isLiveSnapshotEnabled: Bool {
    Self.envFlag("OPENAI_LIVE_SNAPSHOT")
  }

  static var isRecordModeEnabled: Bool {
    Self.envFlag("OPENAI_RECORD_SNAPSHOTS")
  }

  @Test("CreateResponse serializes reasoning settings")
  func createResponseSerializesReasoningSettings() throws {
    let request = CreateResponse(
      responseProperties: ResponseProperties(
        model: .standard(.gpt5_4),
        reasoning: Reasoning(effort: .high, summary: .detailed),
        maxOutputTokens: 512,
        instructions: "Use the project instructions.",
        truncation: .auto
      ),
      inputPayload: CreateResponseInputPayload(
        input: .text("Hello"),
        store: true,
        stream: true
      )
    )

    let data = try JSONEncoder().encode(request.toOpenAPI())
    let json = String(decoding: data, as: UTF8.self)

    #expect(json.contains("\"reasoning\""))
    #expect(json.contains("\"effort\":\"high\""))
    #expect(json.contains("\"summary\":\"detailed\""))
    #expect(json.contains("\"max_output_tokens\":512"))
    #expect(!json.contains("\"maxOutputTokens\":512"))
    #expect(json.contains("\"instructions\":\"Use the project instructions.\""))
    #expect(json.contains("\"stream\":true"))
  }

  @Test("Generated model enums include GPT-5.5 and GPT Image 2")
  func generatedModelEnumsIncludeRequestedModels() throws {
    #expect(Components.Schemas.ModelIdsShared.Value2Payload.gpt5_5.rawValue == "gpt-5.5")
    #expect(CreateImageRequest.Model.gptImage2.rawValue == "gpt-image-2")
    #expect(CreateImageEditRequest.Model.gptImage2.rawValue == "gpt-image-2")
    #expect(ImageGenTool.Model.gptImage2.rawValue == "gpt-image-2")

    let textRequest = CreateResponse(
      responseProperties: ResponseProperties(model: .standard(.gpt5_5)),
      inputPayload: CreateResponseInputPayload(input: .text("ping"))
    )
    let textJSON = String(
      decoding: try JSONEncoder().encode(textRequest.toOpenAPI()), as: UTF8.self)
    #expect(textJSON.contains("\"model\":\"gpt-5.5\""))

    let imageRequest = CreateImageRequest(
      prompt: "small smoke-test square",
      model: .gptImage2,
      n: 1,
      quality: .low,
      size: .size1024x1024
    )
    let imageJSON = String(
      decoding: try JSONEncoder().encode(imageRequest.toOpenAPI()), as: UTF8.self)
    #expect(imageJSON.contains("\"model\":\"gpt-image-2\""))
  }

  @Test("ReasoningEffort maps all OpenAI wire values")
  func reasoningEffortMapsAllOpenAIValues() {
    let cases: [(ReasoningEffort, Components.Schemas.ReasoningEffort)] = [
      (.none, .none),
      (.minimal, .minimal),
      (.low, .low),
      (.medium, .medium),
      (.high, .high),
      (.xhigh, .xhigh),
    ]

    for (effort, openAPI) in cases {
      #expect(effort.toOpenAPI() == openAPI)
      #expect(ReasoningEffort(openAPI: openAPI) == effort)
      #expect(ReasoningEffort(openAPI: effort.rawValue) == effort)
    }

    #expect(ReasoningEffort(openAPI: "unknown") == .medium)
  }

  @Test("Replay local fixtures decode successfully")
  func replaySnapshots() throws {
    for testCase in Self.snapshotCases {
      let fixtureURL = Self.fixturesDirectoryURL.appendingPathComponent(
        "\(testCase.fixtureName).json")
      guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        throw SnapshotTestError.missingFixture(fixtureURL)
      }

      let fixtureData = try Data(contentsOf: fixtureURL)
      try Self.assertSnapshot(data: fixtureData, testCase: testCase)
    }
  }

  @Test("Live snapshot smoke test and optional fixture recording")
  func liveSnapshot() async throws {
    guard Self.isLiveSnapshotEnabled else { return }

    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
      throw SnapshotTestError.missingAPIKey
    }

    if Self.isRecordModeEnabled {
      try FileManager.default.createDirectory(
        at: Self.fixturesDirectoryURL,
        withIntermediateDirectories: true
      )
    }

    for testCase in Self.snapshotCases {
      let rawData = try await Self.fetchLiveResponse(apiKey: apiKey, testCase: testCase)
      let normalizedData = try Self.normalizedSnapshotData(from: rawData)
      try Self.assertSnapshot(data: normalizedData, testCase: testCase)

      if Self.isRecordModeEnabled {
        let fixtureURL = Self.fixturesDirectoryURL.appendingPathComponent("\(testCase.name).json")
        try normalizedData.write(to: fixtureURL, options: .atomic)
      }
    }
  }

  @Test("Live GPT Image 2 smoke test")
  func liveImageSmoke() async throws {
    guard Self.isLiveSnapshotEnabled else { return }

    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
      throw SnapshotTestError.missingAPIKey
    }

    let data = try await Self.fetchLiveImage(apiKey: apiKey)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let images = json?["data"] as? [[String: Any]]
    let firstImage = images?.first
    let b64JSON = firstImage?["b64_json"] as? String

    #expect(b64JSON?.isEmpty == false)
    guard b64JSON?.isEmpty == false else {
      throw SnapshotTestError.missingImagePayload
    }
  }

  static func assertSnapshot(data: Data, testCase: SnapshotCase) throws {
    let decoder = JSONDecoder()
    let openAPIResponse = try decoder.decode(Components.Schemas.Response.self, from: data)
    let response = Response(openAPI: openAPIResponse)

    #expect(response.output.isEmpty == false)
    #expect(response.model != nil)
    #expect(response.outputText.contains(testCase.expectedToken))
  }

  static func fetchLiveResponse(apiKey: String, testCase: SnapshotCase) async throws -> Data {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      preconditionFailure("Invalid OpenAI API URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let payload: [String: Any] = [
      "model": testCase.model,
      "input": testCase.input,
      "max_output_tokens": 32,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, urlResponse) = try await URLSession.shared.data(for: request)
    let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
    guard (200..<300).contains(statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
      throw SnapshotTestError.invalidHTTPStatus(statusCode, body)
    }
    return data
  }

  static func fetchLiveImage(apiKey: String) async throws -> Data {
    guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
      preconditionFailure("Invalid OpenAI image API URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let payload: [String: Any] = [
      "model": "gpt-image-2",
      "prompt": "A tiny blue square icon on a white background.",
      "n": 1,
      "quality": "low",
      "size": "1024x1024",
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, urlResponse) = try await URLSession.shared.data(for: request)
    let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
    guard (200..<300).contains(statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
      throw SnapshotTestError.invalidHTTPStatus(statusCode, body)
    }
    return data
  }

  static func normalizedSnapshotData(from data: Data) throws -> Data {
    let json = try JSONSerialization.jsonObject(with: data)
    let normalized = Self.normalize(json)
    return try JSONSerialization.data(
      withJSONObject: normalized, options: [.prettyPrinted, .sortedKeys])
  }

  static func normalize(_ value: Any, key: String? = nil) -> Any {
    if let dictionary = value as? [String: Any] {
      var result: [String: Any] = [:]
      for (nestedKey, nestedValue) in dictionary {
        result[nestedKey] = Self.normalize(nestedValue, key: nestedKey)
      }
      return result
    }

    if let array = value as? [Any] {
      return array.map { Self.normalize($0) }
    }

    if let key {
      if Self.dynamicStringKeys.contains(key), value is String {
        return "<\(key)>"
      }

      if Self.dynamicNumberKeys.contains(key), value is NSNumber {
        return 0
      }
    }

    return value
  }

  static func envFlag(_ key: String) -> Bool {
    guard
      let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(
        in: .whitespacesAndNewlines),
      !value.isEmpty
    else {
      return false
    }

    switch value.lowercased() {
    case "1", "true", "yes", "y", "on":
      return true
    default:
      return false
    }
  }

  static let dynamicStringKeys: Set<String> = [
    "id",
    "item_id",
    "call_id",
    "response_id",
  ]

  static let dynamicNumberKeys: Set<String> = [
    "created_at",
    "completed_at",
    "sequence_number",
  ]
}
