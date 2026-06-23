import Foundation

struct CoreTaskHistoryResponse: Decodable, Equatable {
    let tasks: [TaskSnapshot]
    let totalCount: Int
    let offset: Int
    let limit: Int
}

struct CoreTaskHistoryClearRequest: Encodable, Equatable {
    let statuses: [String]?
    let olderThanDays: Int?
    let keepFailed: Bool?
}

struct CoreTaskHistoryClearResponse: Decodable, Equatable {
    let deleted: Int
    let kept: Int
    let skippedActive: Int
}
