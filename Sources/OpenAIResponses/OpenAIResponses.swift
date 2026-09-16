import Foundation
import OpenAPIJSONRuntime
import OpenAPIRuntime

extension OpenAIResponsesAPI.Client {
  /// Creates the JSON-only Responses client using OpenAI bearer authentication.
  public init(
    transport: any ClientTransport,
    apiKey: String,
    serverURL: URL? = nil,
    maximumResponseBodyBytes: Int = 16 * 1024 * 1024
  ) throws {
    guard let serverURL = serverURL ?? URL(string: "https://api.openai.com/v1") else {
      throw JSONClientError.invalidBaseURL
    }
    try self.init(
      serverURL: serverURL,
      transport: transport,
      credentials: ResponsesCredentials(apiKey: apiKey),
      maximumResponseBodyBytes: maximumResponseBodyBytes
    )
  }
}

extension OpenAIResponsesAPI.Models.Response {
  /// Concatenates output-text content in message order without changing the response.
  public var outputText: String {
    var fragments: [String] = []
    for item in output {
      guard case .outputMessage(let message) = item else { continue }
      for content in message.content {
        if case .outputText(let text) = content {
          fragments.append(text.text)
        }
      }
    }
    return fragments.joined()
  }
}

extension OpenAIResponsesAPI.Models.CreateResponse {
  /// Creates a text request while keeping the generated initializer available for all other fields.
  public init(input: String, model: String) {
    self.init(
      model: .openapiJsonModelIdsShared(.string(model)),
      input: .string(input)
    )
  }
}
