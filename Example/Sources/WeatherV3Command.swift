import ArgumentParser
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import SwiftDotenv

struct WeatherV3Command: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "weather3",
    abstract: "Demonstrate streaming weather tool calling with swift-openai"
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

    let tools = [WeatherTool(apiKey: Dotenv["OPENWEATHER_API_KEY"]?.stringValue)]

    print("Starting streaming response...")
    print("----------------------------------------")

    let stream = try await client.streamCreateResponse(
      input: .text(prompt),
      model: .standard(.gpt4o),
      tools: tools.map { $0.toTool() }
    )

    for try await event in stream {
      print("event: \(event)")
      switch event {
      case .outputText(let text):
        switch text {
        case .delta(let delta, _, _, _):
          print(delta, terminator: "")
        case .done(let text, _, _, _):
          print(text)
        case .annotation:
          break
        }
      case .functionCallArgument(let args):
        switch args {
        case .delta(let delta, _, _):
          print("\n[Tool Call Arguments: \(delta)]")
        case .done(let arguments, _, _):
          print("\n[Tool Call Complete: \(arguments)]")
        }
      case .completed:
        print("\n----------------------------------------")
        print("Streaming complete")
      case .error(let message, let code, let param):
        print("\nError: \(message) (code: \(code ?? "unknown"), param: \(param ?? "none"))")
      default:
        break
      }
    }
  }
}
