import Foundation

struct PendingContentInstallReview: Identifiable {
    let id = UUID()
    let plan: CoreContentInstallPlanResponse
    let releaseVersionName: String
    let request: CoreContentInstallRequest
    let managedKind: ManagedAssetKind
}
