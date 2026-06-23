import Foundation
import SwiftUI

struct AccountProfile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var avatarURL: URL?
    var lastSignedInAt: Date
    var expiresAt: Date?

    var loginStatus: AccountLoginStatus {
        guard let expiresAt else { return .signedOut }
        if Date() >= expiresAt.addingTimeInterval(-120) {
            return .expired
        }
        return .signedIn
    }
}

enum AccountLoginStatus: String, Codable {
    case signedIn
    case signedOut
    case expired
}

@MainActor
final class AccountStore: ObservableObject {
    @Published var accounts: [AccountProfile] = [] {
        didSet {
            guard !isLoading else { return }
            save()
        }
    }

    @Published var defaultAccountID: String = SettingsStore.string(forKey: "Accounts.DefaultID", default: "") {
        didSet { SettingsStore.set(defaultAccountID, forKey: "Accounts.DefaultID") }
    }

    @Published private(set) var statusMessage = "Accounts not loaded"
    private var isLoading = false

    init() {
        load()
    }

    var defaultAccount: AccountProfile? {
        accounts.first { $0.id == defaultAccountID } ?? accounts.first
    }

    func upsert(account: MinecraftAccount) {
        let profile = AccountProfile(
            id: account.id,
            name: account.name,
            avatarURL: URL(string: "https://crafatar.com/avatars/\(account.id)?overlay"),
            lastSignedInAt: Date(),
            expiresAt: account.expiresAt
        )

        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = profile
        } else {
            accounts.insert(profile, at: 0)
        }

        defaultAccountID = account.id
    }

    func setDefault(_ account: AccountProfile) {
        defaultAccountID = account.id
    }

    func markSignedOut(accountID: String) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[index].expiresAt = nil
    }

    func delete(_ account: AccountProfile) {
        accounts.removeAll { $0.id == account.id }
        if defaultAccountID == account.id {
            defaultAccountID = accounts.first?.id ?? ""
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            let fileURL = try accountsURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                accounts = try JSONDecoder.panino.decode([AccountProfile].self, from: data)
            }
            if defaultAccountID.isEmpty {
                defaultAccountID = accounts.first?.id ?? ""
            }
            statusMessage = "Accounts loaded from \(fileURL.path)"
        } catch {
            statusMessage = "Account load failed: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let fileURL = try accountsURL()
            let data = try JSONEncoder.panino.encode(accounts)
            try data.write(to: fileURL, options: .atomic)
            statusMessage = "Accounts saved at \(fileURL.path)"
        } catch {
            statusMessage = "Account save failed: \(error.localizedDescription)"
        }
    }

    private func accountsURL() throws -> URL {
        try LauncherPaths.appSupportDirectory().appendingPathComponent("accounts.json")
    }
}
