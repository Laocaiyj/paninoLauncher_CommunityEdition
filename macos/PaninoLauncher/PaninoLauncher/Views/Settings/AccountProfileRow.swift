import SwiftUI

struct AccountProfileRow: View {
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
