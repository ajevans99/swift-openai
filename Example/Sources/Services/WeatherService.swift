import Foundation

typealias Location = String

struct WeatherService {
  let apiKey: String?

  enum WeatherError: Error {
    case locationNotFound
    case apiKeyNotFound
  }

  struct GeocodingResult: Decodable {
    let lat: Double
    let lon: Double
  }

  func fetchWeather(for city: String) async throws -> String {
    guard let apiKey = apiKey else {
      throw WeatherError.apiKeyNotFound
    }

    let geoURL = URL(
      string:
        "https://api.openweathermap.org/geo/1.0/direct?q=\(city)&limit=1&appid=\(apiKey)"
    )!
    let geoData = try await URLSession.shared.data(from: geoURL).0
    let loc = try JSONDecoder().decode([GeocodingResult].self, from: geoData)

    guard let loc = loc.first else {
      throw WeatherError.locationNotFound
    }

    let oneCallURL = URL(
      string:
        "https://api.openweathermap.org/data/2.5/weather"
        + "?lat=\(loc.lat)&lon=\(loc.lon)&appid=\(apiKey)"
    )!
    let weatherData = try await URLSession.shared.data(from: oneCallURL).0

    guard let jsonString = String(data: weatherData, encoding: .utf8) else {
      throw URLError(.cannotDecodeRawData)
    }
    return jsonString

  }
}
