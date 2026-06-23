import SwiftUI

extension LaunchDashboard {
    var preflightItems: [LaunchPreflightItem] {
        [
            corePreflightItem,
            javaPreflightItem,
            jvmTuningPreflightItem,
            graphicsPreflightItem,
            versionPreflightItem,
            accountPreflightItem,
            diskPreflightItem,
            resourcePreflightItem
        ]
    }

    var launchPagePreflightItems: [LaunchPreflightItem] {
        let performanceItem = performanceSummaryPreflightItem ?? localPerformancePreflightItem
        let baseItems = [
            corePreflightItem,
            javaPreflightItem,
            performanceItem,
            versionPreflightItem,
            accountPreflightItem,
            diskPreflightItem,
            resourcePreflightItem
        ]
        let blockingItems = baseItems.filter { $0.state == .needsFix }
        if !blockingItems.isEmpty {
            return blockingItems
        }
        return baseItems.filter { $0.id == "performance-summary" || $0.id == "version" || $0.id == "account" }
    }
}
