import Foundation
import Testing

import OpenAICore
import OpenAIFoundation

@Suite("Response Snapshot Tests")
struct ResponseSnapshotTests {
  struct SnapshotCase: Sendable {
    let name: String
    let model: String
    let input: String
    let expectedToken: String
  }

  enum SnapshotTestError: Error {
    case missingAPIKey
    case missingFixture(URL)
    case invalidHTTPStatus(Int, String)
  }

  static let snapshotCases: [SnapshotCase] = [
    .init(
      name: "hello_world_gpt5_2",
      model: "gpt-5.2",
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

  @Test("Replay local fixtures decode successfully")
  func replaySnapshots() throws {
    for testCase in Self.snapshotCases {
      let fixtureURL = Self.fixturesDirectoryURL.appendingPathComponent("\(testCase.name).json")
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
      "temperature": 0,
      "max_output_tokens": 32,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, urlResponse) = try await URLSession.shared.data(for: request)
    let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
    guard (200 ..< 300).contains(statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
      throw SnapshotTestError.invalidHTTPStatus(statusCode, body)
    }
    return data
  }

  static func normalizedSnapshotData(from data: Data) throws -> Data {
    let json = try JSONSerialization.jsonObject(with: data)
    let normalized = Self.normalize(json)
    return try JSONSerialization.data(withJSONObject: normalized, options: [.prettyPrinted, .sortedKeys])
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
    guard let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
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
