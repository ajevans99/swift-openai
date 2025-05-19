import ArgumentParser
import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import SwiftDotenv

struct WeatherCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "weather",
    abstract: "Demonstrate weather tool calling with swift-openai"
  )

  @Argument(help: "The location to get weather for")
  var location: String

  mutating func run() async throws {
    try Dotenv.configure()

    guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
      throw ValidationError("OPENAI_API_KEY is not set")
    }

    let openAI = try OpenAI(
      transport: AsyncHTTPClientTransport(),
      apiKey: apiKey
    )

    let tools = [WeatherTool(apiKey: Dotenv["OPENWEATHER_API_KEY"]?.stringValue)]

    let response = try await openAI.createResponse(
      input: "What's the current weather in \(location)? Please provide a brief summary.",
      model: .standard(.gpt4o),
      tools: tools.map { $0.toTool() }
    )

    var newInputItems = [Item]()
    for output in response.output {
      switch output {
      case .message(let message):
        print("Output", message.content.reduce("") { $0 + $1.text })
      case .functionToolCall(let toolCall):
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
          throw ValidationError("Tool not found: \(toolCall.name)")
        }

        let parameters = try tool.parameters.parse(instance: toolCall.arguments)
        switch parameters {
        case .valid(let parameters):
          do {
            let weather = try await tool.call(parameters: parameters)
            print("Weather tool call result:", weather)

            newInputItems.append(
              .functionCallOutputItemParam(
                .init(callId: toolCall.callId, output: weather)
              )
            )
          } catch {
            print("Error: \(error)")

            newInputItems.append(
              .functionCallOutputItemParam(
                .init(callId: toolCall.callId, output: "Error: \(error)")
              )
            )
          }

        case .invalid(let issues):
          print("Invalid parameters: \(issues)")
          newInputItems.append(
            .functionCallOutputItemParam(
              .init(callId: toolCall.callId, output: "Invalid parameters: \(issues)")
            )
          )
        }
      case .webSearchToolCall, .fileSearchToolCall, .computerToolCall, .reasoning:
        throw ValidationError("Unexpected output item: \(output)")
      }
    }

    let newResponse = try await openAI.createResponse(
      input: .items(newInputItems.map { .item($0) }),
      model: .standard(.gpt4o),
      previousResponseId: response.id
    )

    print("Final output:")
    print(newResponse.outputText)
  }
}

struct WeatherTool: Tool {
  let weatherService: WeatherService

  let name = "get_weather"
  let description: String? = "Get the current weather in a given location."
  let strict = true

  init(apiKey: String?) {
    self.weatherService = WeatherService(apiKey: apiKey)
  }

  var parameters: some JSONSchemaComponent<Location> {
    JSONObject {
      JSONProperty(key: "location") {
        JSONString()
          .description("City and country, e.g. Bogotá, Colombia")
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map(\.0)
  }

  func call(parameters: Location) async throws -> String {
    try await weatherService.fetchWeather(for: parameters)
  }
}
