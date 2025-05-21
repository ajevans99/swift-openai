import Foundation
import Logging

public struct FileLogHandler: LogHandler {
  let fileHandle: FileHandle
  public var metadata: Logger.Metadata = [:]
  public var logLevel: Logger.Level = .debug

  public init(fileHandle: FileHandle) {
    self.fileHandle = fileHandle
  }

  public func log(
    level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String,
    file: String, function: String, line: UInt
  ) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] [\(level)] \(message)\n"
    if let data = logMessage.data(using: .utf8) {
      fileHandle.write(data)
    }
  }

  public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }
}
