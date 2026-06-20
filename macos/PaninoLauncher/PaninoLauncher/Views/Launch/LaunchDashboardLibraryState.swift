import Foundation

extension LaunchDashboard {
    var selectedInstance: GameInstance {
        instanceStore.selectedInstance ?? GameInstance(
            id: Self.fallbackInstanceID,
            name: "Default Game Configuration",
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: viewModel.version,
            gameDirectory: "",
            javaPath: viewModel.javaPath,
            memoryMb: viewModel.memoryMb,
            loader: nil,
            loaderVersion: nil,
            jvmArguments: "",
            preLaunchBehavior: "",
            group: "Default",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: .ready
        )
    }

    var launchAccountProfile: AccountProfile? {
        if let account = viewModel.accountState.account {
            return AccountProfile(
                id: account.id,
                name: account.name,
                avatarURL: URL(string: "https://crafatar.com/avatars/\(account.id)?overlay"),
                lastSignedInAt: Date(),
                expiresAt: account.expiresAt
            )
        }
        return accountStore.defaultAccount
    }

    var recentInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.recentIds {
            return orderedInstances(for: ids).prefix(LaunchLibraryLimits.recentLaunchCount).map { $0 }
        }
        return instanceStore.instances
            .filter { $0.lastLaunchedAt != nil && !$0.isHiddenFromRecent }
            .sorted {
                return ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast)
            }
            .prefix(LaunchLibraryLimits.recentLaunchCount)
            .map { $0 }
    }

    var favoriteInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.favoriteIds {
            return orderedInstances(for: ids).prefix(6).map { $0 }
        }
        return instanceStore.instances
            .filter(\.isFavorite)
            .sorted {
                ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast)
            }
            .prefix(6)
            .map { $0 }
    }

    var recentInstalledInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.recentInstallIds, !ids.isEmpty {
            return orderedInstances(for: ids).prefix(6).map { $0 }
        }
        return instanceStore.instances
            .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(6)
            .map { $0 }
    }

    var detailInstance: GameInstance? {
        guard let detailInstanceID else { return nil }
        return instanceStore.instances.first { $0.id == detailInstanceID }
    }

    var selectedLaunchSummary: CoreLaunchInstanceSummary? {
        summary(for: selectedInstance)
    }

    var launchLibraryRefreshSignature: String {
        instanceStore.instances
            .map { instance in
                [
                    instance.id.uuidString,
                    instance.name,
                    instance.minecraftVersion,
                    instance.loader?.rawValue ?? "vanilla",
                    instance.gameDirectory,
                    instance.status.rawValue,
                    instance.isFavorite ? "favorite" : "normal",
                    instance.isHiddenFromRecent ? "hidden" : "visible",
                    instance.lastLaunchedAt?.timeIntervalSince1970.description ?? "never",
                    instance.lastLaunchState?.rawValue ?? "none",
                    "\(instance.launchCount)"
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }

    var defaultAccountID: String? {
        accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID
    }

    func summary(for instance: GameInstance) -> CoreLaunchInstanceSummary? {
        launchLibrarySummary?.instances.first { summary in
            if summary.id == instance.id.uuidString {
                return true
            }
            return summary.minecraftVersion == instance.minecraftVersion
                && summary.gameDir == instance.gameDirectory
        }
    }

    func orderedInstances(for summaryIds: [String]) -> [GameInstance] {
        summaryIds.compactMap { id in
            instanceStore.instances.first { instance in
                instance.id.uuidString == id || instance.gameDirectory == id
            }
        }
    }
}
