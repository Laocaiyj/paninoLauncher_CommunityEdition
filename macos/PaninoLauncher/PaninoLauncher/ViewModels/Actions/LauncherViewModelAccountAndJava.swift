import Foundation

@MainActor
extension LauncherViewModel {
    func restoreAccountIfPossible(accountID: String? = nil) async {
        guard authService.hasStoredRefreshToken(accountID: accountID), canStartLogin else { return }
        accountState = .restoring
        appendLog("Restoring Microsoft account from Keychain")

        do {
            if let account = try await authService.restoreStoredAccount(clientId: microsoftClientId, accountID: accountID) {
                accountState = .signedIn(account)
                appendLog("Signed in as \(account.name)")
            } else {
                accountState = .signedOut
            }
        } catch {
            accountState = .failed(error.localizedDescription)
            appendLog("Account restore failed: \(error.localizedDescription)")
        }
    }

    func signInWithMicrosoft() {
        guard canStartLogin else {
            accountState = .failed("Enter a Microsoft app client ID first.")
            return
        }

        authTask?.cancel()
        authTask = Task {
            do {
                appendLog("Starting Microsoft device code sign-in")
                let deviceSession = try await authService.startDeviceCode(clientId: microsoftClientId)
                accountState = .waitingForDeviceCode(deviceSession)
                authService.openVerificationURI(deviceSession.verificationURI)
                appendLog("Open \(deviceSession.verificationURI.absoluteString) and enter code \(deviceSession.userCode)")
                let account = try await authService.completeDeviceCodeLogin(clientId: microsoftClientId, session: deviceSession)
                accountState = .signedIn(account)
                appendLog("Signed in as \(account.name)")
            } catch {
                if !Task.isCancelled {
                    accountState = .failed(error.localizedDescription)
                    appendLog("Microsoft sign-in failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelMicrosoftSignIn() {
        authTask?.cancel()
        accountState = .signedOut
        appendLog("Microsoft sign-in cancelled")
    }

    func signOut(accountID: String? = nil) {
        authTask?.cancel()
        do {
            try authService.signOut(accountID: accountID)
            if accountID == nil || accountState.account?.id == accountID {
                accountState = .signedOut
            }
            appendLog("Signed out and removed refresh token from Keychain")
        } catch {
            accountState = .failed(error.localizedDescription)
            appendLog("Sign out failed: \(error.localizedDescription)")
        }
    }

    func launchAccount(accountID: String?) async throws -> MinecraftAccount? {
        if let account = accountState.account, !account.isExpired, accountID == nil || account.id == accountID {
            return account
        }

        if authService.hasStoredRefreshToken(accountID: accountID), canStartLogin {
            accountState = .restoring
            let account = try await authService.restoreStoredAccount(clientId: microsoftClientId, accountID: accountID)
            if let account {
                accountState = .signedIn(account)
            }
            return account
        }

        return nil
    }
}
