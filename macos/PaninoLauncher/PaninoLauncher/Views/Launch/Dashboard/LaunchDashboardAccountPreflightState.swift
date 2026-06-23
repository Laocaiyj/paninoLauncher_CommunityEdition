import SwiftUI

extension LaunchDashboard {
    var accountPreflightItem: LaunchPreflightItem {
        if let account = viewModel.accountState.account, !account.isExpired {
            return LaunchPreflightItem(
                id: "account",
                title: accountPreflightTitle,
                detail: localizedString(theme.language, english: "Signed in as \(account.name).", chinese: "已登录为 \(account.name)。", italian: "Accesso come \(account.name).", french: "Connecté en tant que \(account.name).", spanish: "Sesión iniciada como \(account.name)."),
                state: .ready
            )
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .expired {
            return LaunchPreflightItem(
                id: "account",
                title: accountPreflightTitle,
                detail: localizedString(theme.language, english: "\(profile.name)'s Microsoft session needs refresh.", chinese: "\(profile.name) 的 Microsoft 会话需要刷新。", italian: "La sessione Microsoft di \(profile.name) va aggiornata.", french: "La session Microsoft de \(profile.name) doit être actualisée.", spanish: "La sesión Microsoft de \(profile.name) debe actualizarse."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Refresh", chinese: "刷新", italian: "Aggiorna", french: "Actualiser", spanish: "Actualizar")
            ) {
                Task { await viewModel.restoreAccountIfPossible(accountID: profile.id) }
            }
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .signedIn {
            return LaunchPreflightItem(
                id: "account",
                title: accountPreflightTitle,
                detail: localizedString(theme.language, english: "\(profile.name) is ready for launch.", chinese: "\(profile.name) 可用于启动。", italian: "\(profile.name) pronto per l'avvio.", french: "\(profile.name) prêt pour le lancement.", spanish: "\(profile.name) listo para iniciar."),
                state: .ready
            )
        }
        return LaunchPreflightItem(
            id: "account",
            title: accountPreflightTitle,
            detail: localizedString(theme.language, english: "No online account is selected; launch will use offline fallback where allowed.", chinese: "未选择在线账号；允许时会使用离线回退启动。", italian: "Nessun account online selezionato; verrà usato il fallback offline se consentito.", french: "Aucun compte en ligne sélectionné ; le mode hors ligne sera utilisé si possible.", spanish: "No hay cuenta online seleccionada; se usará modo offline si se permite."),
            state: .optional,
            actionTitle: localizedString(theme.language, english: "Account", chinese: "账号", italian: "Account", french: "Compte", spanish: "Cuenta"),
            action: openAccount
        )
    }

    private var accountPreflightTitle: String {
        AppText.account.localized(theme.language)
    }
}
