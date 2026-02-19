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
        let handle = try await session.stream(
          input,
          additionalItems: [],
          previousResponseID: currentResponseID,
          plugins: TextPlugin()
        )
        let textChannel = handle.pluginEvents

        let completedResponseID = try await withThrowingTaskGroup(of: String?.self) { group in
          group.addTask {
            for try await event in textChannel.events {
              switch event {
              case .delta(let text):
                print(text, terminator: "")
              case .completed:
                print()
              }
            }
            return nil
          }

          group.addTask {
            var responseID: String?
            for try await rawEvent in handle.raw {
              if case .completed(let response) = rawEvent {
                responseID = response.id
              }
            }
            return responseID
          }

          var completedID: String?
          for try await result in group {
            if let result {
              completedID = result
            }
          }
          return completedID
        }

        if let completedResponseID {
          print("\n[Conversation turn completed] \(completedResponseID)")
          currentResponseID = completedResponseID
        }
      } catch {
        print("\nError: \(error.localizedDescription)")
      }
    }
  }
}
