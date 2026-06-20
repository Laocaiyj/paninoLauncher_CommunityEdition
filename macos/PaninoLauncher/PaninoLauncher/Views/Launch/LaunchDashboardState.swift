import SwiftUI

enum LaunchLibraryLimits {
    static let recentLaunchCount = 5
}

extension LaunchDashboard {
    var launchModuleColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 320, maximum: 520),
                spacing: PaninoTokens.Layout.cardSpacing,
                alignment: .top
            )
        ]
    }
}
