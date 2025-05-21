import ArgumentParser
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import SwiftDotenv

struct WeatherV4Command: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "weather4",
    abstract: "Demonstrate streaming weather tool calling with ResponseSession"
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

    guard let weatherApiKey = Dotenv["OPENWEATHER_API_KEY"]?.stringValue else {
      throw ValidationError("OPENWEATHER_API_KEY is not set")
    }

    await session.register(
      tool: WeatherTool(apiKey: weatherApiKey)
    )

    print("Starting streaming response...")
    print("----------------------------------------")

    let stream = try await session.stream(prompt)
    for try await event in stream {
      switch event {
      case .output(let text, let isFinal):
        if isFinal {
          print("Final output: \(text)")
        } else {
          print(text, terminator: "")
        }
      case .toolCalled(let name, let arguments):
        print("\n[Tool Called: \(name)]")
        print("[Arguments: \(arguments)]")
      }
    }
    print("\n----------------------------------------")
    print("Streaming complete")
  }
}
