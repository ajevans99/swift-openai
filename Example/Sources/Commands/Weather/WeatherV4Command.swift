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

    let orchestrator = ToolOrchestratorPlugin(
      tools: [WeatherTool(apiKey: weatherApiKey)]
    )

    print("Starting streaming response...")
    print("----------------------------------------")

    let handle = try await session.stream(
      prompt,
      plugins: TextPlugin(), orchestrator
    )
    let (textChannel, toolChannel) = handle.pluginEvents

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        for try await event in textChannel.events {
          switch event {
          case .delta(let text):
            print(text, terminator: "")
          case .completed(let text):
            print("\nFinal output: \(text)")
          }
        }
      }

      group.addTask {
        for try await event in toolChannel.events {
          if case .executed(let name, let arguments, _, _) = event {
            print("\n[Tool Called: \(name)]")
            print("[Arguments: \(arguments)]")
          }
        }
      }

      group.addTask {
        for try await rawEvent in handle.raw {
          if case .completed(let response) = rawEvent {
            print("\n[Response completed: \(response.id)]")
          }
        }
      }

      try await group.waitForAll()
    }
    print("\n----------------------------------------")
    print("Streaming complete")
  }
}
