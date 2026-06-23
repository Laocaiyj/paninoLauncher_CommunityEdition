import SwiftUI

struct TaowaProfilePanel: View {
    let profiles: [CoreTaowaFrpProfile]
    @Binding var selectedProfileId: String
    let editingProfileId: String?
    @Binding var profileDraft: TaowaProfileDraft
    let profileTest: CoreTaowaFrpProfileTestResponse?
    let isWorking: Bool
    let activeSessionForProfile: (String) -> CoreTaowaSession?
    let onRefresh: () -> Void
    let onNewProfile: () -> Void
    let onCopyAddress: (String, String) -> Void
    let onChooseFrpc: () -> Void
    let onSave: () -> Void
    let onTest: (String) -> Void
    let onDelete: (String) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "FRP Profile", chinese: "FRP 配置", italian: "Profilo FRP", french: "Profil FRP", spanish: "Perfil FRP"),
                        systemImage: "server.rack"
                    )
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: onRefresh)
                        .disabled(isWorking)
                    GlassButton(systemImage: "plus", title: localizedString(theme.language, english: "New", chinese: "新建", italian: "Nuovo", french: "Nouveau", spanish: "Nuevo"), action: onNewProfile)
                        .disabled(isWorking)
                }

                SettingsRow(title: localizedString(theme.language, english: "Profile", chinese: "配置", italian: "Profilo", french: "Profil", spanish: "Perfil"), systemImage: "list.bullet") {
                    Picker("", selection: $selectedProfileId) {
                        Text(localizedString(theme.language, english: "New Profile", chinese: "新配置", italian: "Nuovo profilo", french: "Nouveau profil", spanish: "Nuevo perfil"))
                            .tag("")
                        ForEach(profiles) { profile in
                            Text(profile.displayName).tag(profile.profileId)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 360, alignment: .leading)
                }

                if !profiles.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                        ForEach(profiles) { profile in
                            TaowaProfileCard(
                                profile: profile,
                                isSelected: profile.profileId == selectedProfileId,
                                hasActiveSession: activeSessionForProfile(profile.profileId) != nil,
                                onSelect: {
                                    selectedProfileId = profile.profileId
                                },
                                onCopyAddress: {
                                    onCopyAddress(
                                        profile.remoteAddress,
                                        localizedString(theme.language, english: "Profile remote address copied.", chinese: "配置远程地址已复制。", italian: "Indirizzo remoto copiato.", french: "Adresse distante copiée.", spanish: "Dirección remota copiada.")
                                    )
                                }
                            )
                        }
                    }
                }

                if let profileTest {
                    TaowaProfileTestPanel(test: profileTest)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 10) {
                    SettingsRow(title: localizedString(theme.language, english: "Name", chinese: "名称", italian: "Nome", french: "Nom", spanish: "Nombre"), systemImage: "tag") {
                        PaninoTextInput("My FRP", text: $profileDraft.displayName)
                    }
                    SettingsRow(title: "Server", systemImage: "network") {
                        PaninoTextInput("frp.example.com", text: $profileDraft.serverAddr)
                    }
                    SettingsRow(title: "Server Port", systemImage: "number") {
                        PaninoTextInput("7000", text: $profileDraft.serverPort)
                    }
                    SettingsRow(title: "Remote Port", systemImage: "number.circle") {
                        PaninoTextInput("25565", text: $profileDraft.remotePort)
                    }
                    SettingsRow(title: "Token", systemImage: "key") {
                        PaninoTextInput(profileDraft.hasExistingToken ? "Keep existing token" : "Optional", text: $profileDraft.token, isSecure: true)
                    }
                    SettingsRow(title: "frpc", systemImage: "terminal") {
                        HStack(spacing: 8) {
                            PaninoTextInput("/path/to/frpc", text: $profileDraft.frpcPath)
                            GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Choose", chinese: "选择", italian: "Scegli", french: "Choisir", spanish: "Elegir"), action: onChooseFrpc)
                        }
                    }
                    SettingsRow(title: localizedString(theme.language, english: "Enabled", chinese: "启用", italian: "Abilitato", french: "Activé", spanish: "Activado"), systemImage: "checkmark.circle") {
                        Toggle("", isOn: $profileDraft.enabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checkmark", title: localizedString(theme.language, english: "Save", chinese: "保存", italian: "Salva", french: "Enregistrer", spanish: "Guardar"), prominent: true, action: onSave)
                        .disabled(isWorking)
                    if let editingProfileId {
                        GlassButton(systemImage: "checkmark.shield", title: localizedString(theme.language, english: "Test", chinese: "测试", italian: "Test", french: "Tester", spanish: "Probar")) {
                            onTest(editingProfileId)
                        }
                        .disabled(isWorking)
                        GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                            onDelete(editingProfileId)
                        }
                        .disabled(isWorking || activeSessionForProfile(editingProfileId) != nil)
                    }
                }
            }
        }
    }
}
