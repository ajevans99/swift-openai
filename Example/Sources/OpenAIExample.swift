// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import OpenAI
import OpenAPIAsyncHTTPClient
import SwiftDotenv

let debugString = #"""
  {
    "parallel_tool_calls" : true,
    "top_p" : 1,
    "status" : "completed",
    "metadata" : {

    },
    "temperature" : 1,
    "tools" : [
      {
        "parameters" : {
          "properties" : {
            "location" : {
              "type" : "string",
              "description" : "City and country, e.g. Bogotá, Colombia"
            }
          },
          "required" : [
            "location"
          ],
          "type" : "object",
          "additionalProperties" : false
        },
        "strict" : true,
        "type" : "function",
        "description" : "Get the current weather in a given location.",
        "name" : "get_weather"
      }
    ],
    "incomplete_details" : null,
    "object" : "response",
    "previous_response_id" : null,
    "store" : true,
    "max_output_tokens" : null,
    "instructions" : null,
    "service_tier" : "default",
    "id" : "resp_68269a09e58c8191ba08e477bab5315f0293b036c87143ed",
    "usage" : {
      "input_tokens" : 65,
      "output_tokens" : 17,
      "total_tokens" : 82,
      "output_tokens_details" : {
        "reasoning_tokens" : 0
      },
      "input_tokens_details" : {
        "cached_tokens" : 0
      }
    },
    "user" : null,
    "error" : null,
    "reasoning" : {
      "effort" : null,
      "summary" : null
    },
    "model" : "gpt-4o-2024-08-06",
    "tool_choice" : "auto",
    "text" : {
      "format" : {
        "type" : "text"
      }
    },
    "created_at" : 1747360265,
    "truncation" : "disabled",
    "output" : [
      {
        "status" : "completed",
        "id" : "fc_68269a0a54708191b0bb05a2eb04e1b30293b036c87143ed",
        "arguments" : "{\"location\":\"Detroit, USA\"}",
        "call_id" : "call_PsOvyW74sBureszDT8aqokMk",
        "type" : "function_call",
        "name" : "get_weather"
      }
    ]
  }
  """#

@main
struct OpenAIExample: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "OpenAI CLI example",
    subcommands: [WeatherCommand.self]
  )

  mutating func run() async throws {
    // try Dotenv.configure()

    // guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
    //   throw ValidationError("OPENAI_API_KEY is not set")
    // }

    // let openAI = try OpenAI(
    //   transport: AsyncHTTPClientTransport(),
    //   apiKey: apiKey
    // )

    // let response = try await openAI.createResponse(
    //   input: "Hello, world!",
    //   model: .gpt4o
    // )

    // dump(response)
    // print("Output text: \(response.outputText)")

    let response = try JSONDecoder().decode(
      Components.Schemas.Response.self, from: debugString.data(using: .utf8)!)
    dump(response)
  }
}
