import OpenAICore

public protocol HistoryBuffer {
  /// All stored entries, oldest first.
  var entries: [Item] { get }

  mutating func appendUser(_ text: String)

  mutating func appendResponse(responseID: String, items: [Item])
}

public struct RolllingHistoryBuffer: HistoryBuffer {
  public private(set) var entries: [Item] = []
  private let capacity: Int

  public init(capacity: Int) {
    self.capacity = capacity
  }

  public mutating func appendUser(_ text: String) {
    entries.append(.inputMessage(InputMessage(role: .user, content: [.text(.init(text: text))])))
  }

  public mutating func appendResponse(responseID: String, items: [Item]) {
    entries.append(contentsOf: items)

    if entries.count > capacity {
      entries.removeFirst(entries.count - capacity)
    }
  }
}
