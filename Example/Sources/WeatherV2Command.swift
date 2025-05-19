import ArgumentParser
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import SwiftDotenv

struct WeatherV2Command: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "weather2",
    abstract: "Demonstrate weather tool calling with swift-openai"
  )

  @Argument(help: "The prompt to send to the assistant")
  var prompt: String

  mutating func run() async throws {
    try Dotenv.configure()

    guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
      throw ValidationError("OPENAI_API_KEY is not set")
    }

    let client = try OpenAI(
      transport: AsyncHTTPClientTransport(),
      apiKey: apiKey
    )

    let session = ResponseSession(client: client, model: .standard(.gpt4o))
    await session.register(
      tool: WeatherTool(apiKey: Dotenv["OPENWEATHER_API_KEY"]?.stringValue)
    )

    let response = try await session.send(prompt)
    print(response)
  }
}
