import ArgumentParser
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import SwiftDotenv

enum OpenAIFactory {
  static func create() throws -> OpenAI {
    try Dotenv.configure()

    guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
      throw ValidationError("OPENAI_API_KEY is not set")
    }

    let client = try OpenAI(
      transport: AsyncHTTPClientTransport(configuration: .init(timeout: .hours(1))),
      apiKey: apiKey
    )

    return client
  }
}
