import OpenAPIRuntime

public struct ListQueryItems {
  public enum Order: String {
    case asc
    case desc

    public func toOpenAPI() -> Operations.ListInputItems.Input.Query.OrderPayload {
      switch self {
      case .asc: return .asc
      case .desc: return .desc
      }
    }
  }

  public let after: String?
  public let before: String?
  public let limit: Int?
  public let order: Order?
  public let include: [Includable]?

  public init(
    after: String? = nil,
    before: String? = nil,
    limit: Int? = nil,
    order: Order? = nil,
    include: [Includable]? = nil
  ) {
    self.after = after
    self.before = before
    self.limit = limit
    self.order = order
    self.include = include
  }

  public func toOpenAPI() -> Operations.ListInputItems.Input.Query {
    .init(
      limit: limit,
      order: order?.toOpenAPI(),
      after: after,
      before: before,
      include: include?.map { $0.toOpenAPI() }
    )
  }
}

public struct ListInputItemsResponse {
  public let data: [Components.Schemas.ItemResource]
  public let firstId: String
  public let hasMore: Bool
  public let lastId: String
  public let object = "list"

  public init(openAPI: Components.Schemas.ResponseItemList) {
    self.data = openAPI.data
    self.firstId = openAPI.firstId
    self.hasMore = openAPI.hasMore
    self.lastId = openAPI.lastId
  }
}
