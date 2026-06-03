import SwiftUI

private struct AccountPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @State private var pendingDeleteAccount: AccountProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            AccountCard(accountState: viewModel.accountState)

            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack {
                        PanelHeader(
                            title: localizedString(theme.language, english: "Microsoft Accounts", chinese: "Microsoft 账号", italian: "Account Microsoft", french: "Comptes Microsoft", spanish: "Cuentas Microsoft"),
                            systemImage: "person.2.crop.square.stack"
                        )
                        Spacer()
                        GlassButton(systemImage: "person.crop.circle.badge.plus", title: localizedString(theme.language, english: "Sign In", chinese: "登录", italian: "Accedi", french: "Se connecter", spanish: "Iniciar sesión"), prominent: true) {
                            viewModel.signInWithMicrosoft()
                        }
                        .disabled(!viewModel.canStartLogin)
                    }

                    if launcherSettings.advancedModeEnabled {
                        SettingsRow(title: "Client ID", systemImage: "key") {
                            PaninoTextInput(
                                localizedString(theme.language, english: "Developer Client ID override", chinese: "开发者 Client ID 覆盖", italian: "Override Client ID sviluppatore", french: "Client ID développeur", spanish: "Client ID de desarrollo"),
                                text: $viewModel.microsoftClientId,
                                isSecure: true
                            )
                        }
                    } else if !viewModel.canStartLogin {
                        StatusBadge(
                            title: localizedString(theme.language, english: "Client ID is not configured in this build", chinese: "此构建未配置 Client ID", italian: "Client ID non configurato in questa build", french: "Client ID non configuré dans cette version", spanish: "Client ID no configurado en esta build"),
                            style: .warning
                        )
                    }

                    if accountStore.accounts.isEmpty {
                        ContentUnavailableView(
                            localizedString(theme.language, english: "No Microsoft Accounts", chinese: "没有 Microsoft 账号", italian: "Nessun account Microsoft", french: "Aucun compte Microsoft", spanish: "Sin cuentas Microsoft"),
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text(localizedString(theme.language, english: "Sign in to add an account. Tokens are stored only in Keychain.", chinese: "登录以添加账号。令牌只存储在钥匙串中。", italian: "Accedi per aggiungere un account. I token restano solo nel Portachiavi.", french: "Connectez-vous pour ajouter un compte. Les jetons restent uniquement dans le trousseau.", spanish: "Inicia sesión para añadir una cuenta. Los tokens solo se guardan en el llavero."))
                        )
                        .frame(minHeight: 160)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(accountStore.accounts) { account in
                                AccountProfileRow(
                                    account: account,
                                    isDefault: accountStore.defaultAccount?.id == account.id,
                                    isCurrent: viewModel.accountState.account?.id == account.id,
                                    onMakeDefault: {
                                        accountStore.setDefault(account)
                                        Task {
                                            await viewModel.restoreAccountIfPossible(accountID: account.id)
                                        }
                                    },
                                    onSignOut: {
                                        viewModel.signOut(accountID: account.id)
                                        accountStore.markSignedOut(accountID: account.id)
                                    },
                                    onReauthenticate: {
                                        Task {
                                            await viewModel.restoreAccountIfPossible(accountID: account.id)
                                        }
                                    },
                                    onDelete: {
                                        pendingDeleteAccount = account
                                    }
                                )
                            }
                        }
                    }

                    Text(localizedString(theme.language, english: "Security: access tokens stay in memory only, refresh tokens are stored in Keychain, and logs are redacted before display/export.", chinese: "安全：访问令牌只保存在内存中，刷新令牌存储在钥匙串中，日志在显示和导出前会脱敏。", italian: "Sicurezza: gli access token restano in memoria, i refresh token nel Portachiavi e i log vengono oscurati prima di vista/export.", french: "Sécurité : les jetons d'accès restent en mémoire, les jetons de rafraîchissement dans le trousseau, et les journaux sont masqués avant affichage/export.", spanish: "Seguridad: los access tokens quedan en memoria, los refresh tokens en llavero y los registros se redactan antes de mostrar/exportar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if let account = viewModel.accountState.account, account.isExpired {
                        HStack {
                            StatusBadge(title: localizedString(theme.language, english: "Login expired", chinese: "登录已过期", italian: "Accesso scaduto", french: "Connexion expirée", spanish: "Inicio expirado"), style: .warning)
                            GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Re-authenticate", chinese: "重新登录", italian: "Riautentica", french: "Réauthentifier", spanish: "Reautenticar")) {
                                Task {
                                    await viewModel.restoreAccountIfPossible(accountID: account.id)
                                }
                            }
                        }
                    }

                    if case .waitingForDeviceCode(let session) = viewModel.accountState {
                        DeviceCodePanel(session: session) {
                            viewModel.cancelMicrosoftSignIn()
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete this account?", chinese: "删除这个账号？", italian: "Eliminare questo account?", french: "Supprimer ce compte ?", spanish: "¿Eliminar esta cuenta?"),
            isPresented: Binding(
                get: { pendingDeleteAccount != nil },
                set: { if !$0 { pendingDeleteAccount = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Delete Account", chinese: "删除账号", italian: "Elimina account", french: "Supprimer le compte", spanish: "Eliminar cuenta"), role: .destructive) {
                if let pendingDeleteAccount {
                    viewModel.signOut(accountID: pendingDeleteAccount.id)
                    accountStore.delete(pendingDeleteAccount)
                }
                pendingDeleteAccount = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingDeleteAccount = nil
            }
        }
    }
}

private struct AccountProfileRow: View {
    let account: AccountProfile
    let isDefault: Bool
    let isCurrent: Bool
    let onMakeDefault: () -> Void
    let onSignOut: () -> Void
    let onReauthenticate: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(profile: account)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(account.name)
                        .font(.headline)
                        .lineLimit(1)
                    if isDefault {
                        StatusBadge(title: localizedString(theme.language, english: "Default", chinese: "默认", italian: "Predefinito", french: "Par défaut", spanish: "Predeterminada"), style: .download)
                    }
                    if isCurrent {
                        StatusBadge(title: localizedString(theme.language, english: "Active", chinese: "当前", italian: "Attivo", french: "Actif", spanish: "Activa"), style: .success)
                    }
                }
                Text(account.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(
                    localizedString(theme.language, english: "Last sign-in", chinese: "上次登录", italian: "Ultimo accesso", french: "Dernière connexion", spanish: "Último inicio")
                        + " \(account.lastSignedInAt.formatted(date: .abbreviated, time: .shortened))"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(title: account.loginStatus.title(language: theme.language), style: account.loginStatus.badgeStyle)

            Menu {
                Button(localizedString(theme.language, english: "Make Default", chinese: "设为默认", italian: "Imposta predefinito", french: "Définir par défaut", spanish: "Usar como predeterminada"), action: onMakeDefault)
                Button(localizedString(theme.language, english: "Re-authenticate", chinese: "重新登录", italian: "Riautentica", french: "Réauthentifier", spanish: "Reautenticar"), action: onReauthenticate)
                Button(localizedString(theme.language, english: "Sign Out", chinese: "退出登录", italian: "Esci", french: "Se déconnecter", spanish: "Cerrar sesión"), action: onSignOut)
                Divider()
                Button(localizedString(theme.language, english: "Delete Account", chinese: "删除账号", italian: "Elimina account", french: "Supprimer le compte", spanish: "Eliminar cuenta"), role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.button)
            .accessibilityLabel(localizedString(theme.language, english: "Account Actions", chinese: "账号操作", italian: "Azioni account", french: "Actions du compte", spanish: "Acciones de cuenta"))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct AccountAvatar: View {
    let profile: AccountProfile

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
            if let avatarURL = profile.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle")
                    }
                }
            } else {
                Image(systemName: "person.crop.circle")
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
    }
}
