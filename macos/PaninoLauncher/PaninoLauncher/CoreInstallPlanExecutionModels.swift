import Foundation

struct CoreInstallNodeResult: Decodable, Equatable, Sendable {
    let nodeId: String
    let status: String
    let message: String?
    let diagnostic: CoreDiagnostic?
}

struct CoreInstallPlanExecutionResult: Decodable, Equatable, Sendable {
    let planId: String
    let status: String
    let results: [CoreInstallNodeResult]
    let completedNodeIds: [String]
    let failedNodeId: String?
    let rolledBackNodeIds: [String]
}
