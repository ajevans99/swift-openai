import Foundation

struct StreamingSSEEvent: Sendable {
  var event: String?
  var data: String?
  var id: String?
  var retry: Int64?
}

struct StreamingSSEParser {
  private enum Byte {
    static let lineFeed: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let colon: UInt8 = 0x3A
    static let space: UInt8 = 0x20
  }

  private struct MutableEvent {
    var event: String?
    var data: String?
    var id: String?
    var retry: Int64?
    var hasFields: Bool = false
  }

  private var currentLine: [UInt8] = []
  private var pendingCarriageReturn = false
  private var event = MutableEvent()

  mutating func consume(_ chunk: ArraySlice<UInt8>) -> [StreamingSSEEvent] {
    var emitted: [StreamingSSEEvent] = []

    for byte in chunk {
      if pendingCarriageReturn {
        pendingCarriageReturn = false
        if byte == Byte.lineFeed {
          continue
        }
      }

      if byte == Byte.lineFeed {
        flushCurrentLine(into: &emitted)
      } else if byte == Byte.carriageReturn {
        flushCurrentLine(into: &emitted)
        pendingCarriageReturn = true
      } else {
        currentLine.append(byte)
      }
    }

    return emitted
  }

  mutating func finish() -> [StreamingSSEEvent] {
    // By spec, incomplete events are discarded on end-of-stream.
    []
  }

  private mutating func flushCurrentLine(into emitted: inout [StreamingSSEEvent]) {
    defer { currentLine.removeAll(keepingCapacity: true) }

    if currentLine.isEmpty {
      flushEvent(into: &emitted)
      return
    }

    if currentLine.first == Byte.colon {
      return
    }

    guard
      let separatorIndex = currentLine.firstIndex(of: Byte.colon),
      separatorIndex < currentLine.endIndex
    else {
      return
    }

    let field = String(decoding: currentLine[..<separatorIndex], as: UTF8.self)
    let valueStartIndex = currentLine.index(after: separatorIndex)
    let rawValue = currentLine[valueStartIndex...]
    let valueBytes: ArraySlice<UInt8>
    if rawValue.first == Byte.space {
      valueBytes = rawValue.dropFirst()
    } else {
      valueBytes = rawValue
    }

    let value = String(decoding: valueBytes, as: UTF8.self)

    switch field {
    case "event":
      event.event = value
      event.hasFields = true
    case "data":
      if var existing = event.data {
        existing.append(value)
        existing.append("\n")
        event.data = existing
      } else {
        event.data = value + "\n"
      }
      event.hasFields = true
    case "id":
      event.id = value
      event.hasFields = true
    case "retry":
      guard let retry = Int64(value) else { return }
      event.retry = retry
      event.hasFields = true
    default:
      return
    }
  }

  private mutating func flushEvent(into emitted: inout [StreamingSSEEvent]) {
    guard event.hasFields else { return }

    var data = event.data
    if data?.hasSuffix("\n") == true {
      data?.removeLast()
    }

    emitted.append(
      StreamingSSEEvent(
        event: event.event,
        data: data,
        id: event.id,
        retry: event.retry
      )
    )
    event = MutableEvent()
  }
}
