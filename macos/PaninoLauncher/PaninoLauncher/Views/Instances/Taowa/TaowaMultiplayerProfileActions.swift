import AppKit
import SwiftUI

extension TaowaMultiplayerPage {
    func saveProfile() async {
        guard let request = profileDraft.request(profileId: editingProfileId) else {
            errorText = localizedString(theme.language, english: "Fill server address, ports, and frpc path.", chinese: "请填写服务器地址、端口和 frpc 路径。", italian: "Compila server, porte e percorso frpc.", french: "Renseignez serveur, ports et chemin frpc.", spanish: "Completa servidor, puertos y ruta frpc.")
            return
        }
        isWorking = true
        errorText = nil
        do {
            let saved = try await viewModel.saveTaowaFrpProfile(profileId: editingProfileId, request: request)
            selectedProfileId = saved.profileId
            profileTest = nil
            statusText = localizedString(theme.language, english: "FRP profile saved.", chinese: "FRP 配置已保存。", italian: "Profilo FRP salvato.", french: "Profil FRP enregistré.", spanish: "Perfil FRP guardado.")
            await loadState()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func testProfile(_ profileId: String) async {
        isWorking = true
        errorText = nil
        do {
            let response = try await viewModel.testTaowaFrpProfile(profileId: profileId)
            profileTest = response
            statusText = response.ok
                ? localizedString(theme.language, english: "FRP profile test passed.", chinese: "FRP 配置测试通过。", italian: "Test profilo FRP riuscito.", french: "Test du profil FRP réussi.", spanish: "Prueba del perfil FRP superada.")
                : localizedString(theme.language, english: "FRP profile test found issues.", chinese: "FRP 配置测试发现问题。", italian: "Test profilo FRP con problemi.", french: "Le test du profil FRP a trouvé des problèmes.", spanish: "La prueba del perfil FRP encontró problemas.")
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func deleteProfile(_ profileId: String) async {
        isWorking = true
        errorText = nil
        do {
            _ = try await viewModel.deleteTaowaFrpProfile(profileId: profileId)
            startNewProfile()
            profileTest = nil
            statusText = localizedString(theme.language, english: "FRP profile deleted.", chinese: "FRP 配置已删除。", italian: "Profilo FRP eliminato.", french: "Profil FRP supprimé.", spanish: "Perfil FRP eliminado.")
            await loadState()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }

    func startNewProfile() {
        selectedProfileId = ""
        editingProfileId = nil
        profileDraft = TaowaProfileDraft()
    }

    func loadSelectedProfileIntoDraft() {
        guard let profile = profiles.first(where: { $0.profileId == selectedProfileId }) else {
            editingProfileId = nil
            if selectedProfileId.isEmpty {
                profileDraft = TaowaProfileDraft()
                profileTest = nil
            }
            return
        }
        editingProfileId = profile.profileId
        profileDraft = TaowaProfileDraft(profile: profile)
        if profileTest?.profileId != profile.profileId {
            profileTest = nil
        }
    }

    func chooseFrpc() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = localizedString(theme.language, english: "Choose the frpc executable from your FRP provider.", chinese: "选择第三方 FRP 服务提供的 frpc 可执行文件。", italian: "Scegli eseguibile frpc.", french: "Choisissez l'exécutable frpc.", spanish: "Elige el ejecutable frpc.")
        if panel.runModal() == .OK, let url = panel.url {
            profileDraft.frpcPath = url.path
        }
    }
}
