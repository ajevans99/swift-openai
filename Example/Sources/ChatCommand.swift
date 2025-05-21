import ArgumentParser
import Foundation
import Logging
import OpenAIKit

struct ChatCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "chat",
    abstract: "Interactive chat with OpenAI using streaming responses"
  )

  @Option(name: .long, help: "Previous response ID to continue conversation")
  var previousID: String?

  func run() async throws {
    // Create logs directory if it doesn't exist
    let sourceFile = URL(fileURLWithPath: #file)
    let logsDir =
      sourceFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("logs")
    try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

    // Set up file-based logging
    let logFile = logsDir.appendingPathComponent("chat.log")
    if !FileManager.default.fileExists(atPath: logFile.path) {
      FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }
    let fileHandle = try FileHandle(forWritingTo: logFile)
    fileHandle.seekToEndOfFile()

    var logger = Logger(label: "chat")
    logger.logLevel = .debug
    logger.handler = FileLogHandler(fileHandle: fileHandle)

    let client = try OpenAIFactory.create(logger: logger)
    let session = ResponseSession(client: client, model: .standard(.gpt4o))

    print("Chat started. Type 'exit' to quit.")
    print("--------------------------------")

    var currentResponseID = previousID

    while true {
      print("\nYou: ", terminator: "")
      guard let input = readLine(), !input.isEmpty else { continue }

      if input.lowercased() == "exit" {
        print("\nGoodbye!")
        break
      }

      print("\nAssistant: ", terminator: "")

      do {
        let stream = try await session.stream(input, previousResponseID: currentResponseID)

        for try await event in stream {
          switch event {
          case .output(let text, let isFinal):
            if isFinal {
              print()
            } else {
              print(text, terminator: "")
            }
          case .toolCalled(let name, let arguments):
            print("\n[Tool called: \(name)]")
            print("Arguments: \(arguments)")
          case .completed(let responseID):
            print("\n[Conversation turn completed] \(responseID)")
            currentResponseID = responseID
          }
        }
      } catch {
        print("\nError: \(error.localizedDescription)")
      }
    }
  }
}
