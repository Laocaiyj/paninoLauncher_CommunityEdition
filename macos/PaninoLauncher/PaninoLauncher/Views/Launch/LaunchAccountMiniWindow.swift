import SwiftUI

struct LaunchAccountMiniWindow: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openAccountSettings: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var instanceStore: InstanceStore

    var body: some View {
        GlassPanel {
            HStack(spacing: 10) {
                Image(systemName: accountIcon)
                    .font(.headline)
                    .foregroundStyle(accountStatusStyle.color)
                    .frame(width: 28, height: 28)
                    .background(accountStatusStyle.color.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(accountTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(instanceLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 6)

                StatusBadge(title: accountStatusTitle, style: accountStatusStyle)

                Menu {
                    if viewModel.accountState.account != nil {
                        Button(localizedString(theme.language, english: "Re-authenticate", chinese: "重新登录", italian: "Riautentica", french: "Réauthentifier", spanish: "Reautenticar")) {
                            restoreDefaultAccount()
                        }
                        Button(localizedString(theme.language, english: "Sign Out", chinese: "退出登录", italian: "Esci", french: "Se déconnecter", spanish: "Cerrar sesión")) {
                            signOutCurrentAccount()
                        }
                    } else {
                        Button(localizedString(theme.language, english: "Sign In", chinese: "登录", italian: "Accedi", french: "Se connecter", spanish: "Iniciar sesión")) {
                            viewModel.signInWithMicrosoft()
                        }
                        .disabled(!viewModel.canStartLogin)
                    }

                    if !accountStore.accounts.isEmpty {
                        Divider()
                        ForEach(accountStore.accounts) { account in
                            Button(account.name) {
                                accountStore.setDefault(account)
                                Task {
                                    await viewModel.restoreAccountIfPossible(accountID: account.id)
                                }
                            }
                        }
                    }

                    Divider()
                    Button(AppText.settings.localized(theme.language), action: openAccountSettings)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.button)
                .help(localizedString(theme.language, english: "Account options", chinese: "账号选项", italian: "Opzioni account", french: "Options du compte", spanish: "Opciones de cuenta"))
            }
        }
    }

    private var accountTitle: String {
        if let account = viewModel.accountState.account {
            return account.name
        }
        if let account = accountStore.defaultAccount {
            return account.name
        }
        return AppText.microsoftAccount.localized(theme.language)
    }

    private var instanceLine: String {
        guard let instance = instanceStore.selectedInstance else {
            return localizedString(theme.language, english: "No configuration selected", chinese: "未选择游戏配置", italian: "Nessuna configurazione", french: "Aucune configuration", spanish: "Sin configuración")
        }
        return "\(instance.name) · \(instance.minecraftVersion)"
    }

    private var accountStatusTitle: String {
        switch viewModel.accountState {
        case .signedIn:
            return AppText.signedIn.localized(theme.language)
        case .restoring:
            return AppText.restoring.localized(theme.language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(theme.language)
        case .failed:
            return AppText.error.localized(theme.language)
        case .signedOut:
            return accountStore.defaultAccount?.loginStatus.title(language: theme.language)
                ?? AppText.signedOut.localized(theme.language)
        }
    }

    private var accountStatusStyle: StatusBadge.Style {
        switch viewModel.accountState {
        case .signedIn:
            return .success
        case .restoring, .waitingForDeviceCode:
            return .running
        case .failed:
            return .error
        case .signedOut:
            return accountStore.defaultAccount?.loginStatus.badgeStyle ?? .neutral
        }
    }

    private var accountIcon: String {
        switch viewModel.accountState {
        case .signedIn:
            return "person.crop.circle.fill.badge.checkmark"
        case .restoring, .waitingForDeviceCode:
            return "person.crop.circle.badge.clock"
        case .failed:
            return "person.crop.circle.badge.exclamationmark"
        case .signedOut:
            return "person.crop.circle"
        }
    }

    private func restoreDefaultAccount() {
        Task {
            await viewModel.restoreAccountIfPossible(accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID)
        }
    }

    private func signOutCurrentAccount() {
        guard let account = viewModel.accountState.account else { return }
        viewModel.signOut(accountID: account.id)
        accountStore.markSignedOut(accountID: account.id)
    }
}
