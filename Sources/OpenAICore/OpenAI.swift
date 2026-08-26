import Foundation
import Logging
@_exported import OpenAIFoundation
import OpenAPIRuntime

public struct OpenAI: Sendable {
  let openAPIClient: Client
  public let logger: Logger

  public init(
    transport: any ClientTransport,
    apiKey: String,
    serverURL: URL? = nil,
    logger: Logger? = nil
  ) throws {
    var logger = logger ?? Logger(label: "swift-openai")
    logger.logLevel = .debug
    let resolvedServerURL = try serverURL ?? Servers.Server1.url()

    openAPIClient = Client(
      serverURL: resolvedServerURL,
      transport: transport,
      middlewares: [
        AuthenticationMiddleware(bearerToken: apiKey),
        LoggingMiddleware(logger: logger, bodyLoggingConfiguration: .upTo(maxBytes: 2500)),
        // DebugBodyMiddleware(),
      ]
    )
    self.logger = logger
  }
}
