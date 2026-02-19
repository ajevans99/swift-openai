import ArgumentParser
import AsyncHTTPClient
import Logging
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import SwiftDotenv

enum OpenAIFactory {
  // Keep this process-wide to avoid shutdown/deinit issues for short-lived CLI runs.
  private static let http1Client: HTTPClient = {
    var configuration = HTTPClient.Configuration()
    configuration.httpVersion = .http1Only
    // If the stream goes silent for too long, force a reconnect path so ResponseSession
    // can recover by polling the terminal response.
    configuration.timeout = .init(connect: .seconds(30), read: .seconds(30))
    return HTTPClient(eventLoopGroupProvider: .singleton, configuration: configuration)
  }()

  static func create(logger: Logger? = nil) throws -> OpenAI {
    try Dotenv.configure()

    guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
      throw ValidationError("OPENAI_API_KEY is not set")
    }

    let client = try OpenAI(
      transport: AsyncHTTPClientTransport(
        configuration: .init(client: Self.http1Client, timeout: .hours(1))
      ),
      apiKey: apiKey,
      logger: logger
    )

    return client
  }
}
