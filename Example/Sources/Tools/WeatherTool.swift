import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit

struct WeatherTool: Toolable {
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
