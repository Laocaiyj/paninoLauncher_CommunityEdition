import SwiftUI

enum TaowaMultiplayerPresentation {
    static func startHintText(
        language: AppLanguage,
        selectedProfile: CoreTaowaFrpProfile?,
        parsedLocalPort: Int?,
        runningSession: CoreTaowaSession?,
        detection: CoreTaowaLanPortDetection?
    ) -> String? {
        if selectedProfile == nil {
            return localizedString(language, english: "Choose or save an FRP profile before starting.", chinese: "启动前请选择或保存一个 FRP 配置。", italian: "Scegli o salva un profilo FRP prima di avviare.", french: "Choisissez ou enregistrez un profil FRP avant de démarrer.", spanish: "Elige o guarda un perfil FRP antes de iniciar.")
        }
        if selectedProfile?.enabled == false {
            return localizedString(language, english: "The selected FRP profile is disabled.", chinese: "当前 FRP 配置已停用。", italian: "Il profilo FRP selezionato è disabilitato.", french: "Le profil FRP sélectionné est désactivé.", spanish: "El perfil FRP seleccionado está desactivado.")
        }
        if parsedLocalPort == nil {
            return localizedString(language, english: "Open the world to LAN in Minecraft, then detect or enter the LAN port.", chinese: "先在 Minecraft 单人世界中“对局域网开放”，再检测或输入 LAN 端口。", italian: "Apri il mondo alla LAN, poi rileva o inserisci la porta.", french: "Ouvrez le monde au LAN, puis détectez ou saisissez le port.", spanish: "Abre el mundo a LAN y luego detecta o introduce el puerto.")
        }
        if runningSession != nil {
            return localizedString(language, english: "A Taowa tunnel is already running for this instance.", chinese: "这个实例已经有正在运行的陶瓦隧道。", italian: "Un tunnel Taowa è già in esecuzione.", french: "Un tunnel Taowa est déjà en cours.", spanish: "Ya hay un túnel Taowa en ejecución.")
        }
        if detection?.isDetected != true {
            return localizedString(language, english: "Port validation is recommended. Core will still verify the port before starting frpc.", chinese: "建议先校验端口。启动时 Core 仍会再次校验本地端口。", italian: "La verifica della porta è consigliata.", french: "La validation du port est recommandée.", spanish: "Se recomienda validar el puerto.")
        }
        return nil
    }

    static func workflowSteps(
        language: AppLanguage,
        selectedProfile: CoreTaowaFrpProfile?,
        parsedLocalPort: Int?,
        detection: CoreTaowaLanPortDetection?,
        runningSession: CoreTaowaSession?
    ) -> [TaowaWorkflowStep] {
        [
            TaowaWorkflowStep(
                id: "profile",
                title: localizedString(language, english: "FRP profile", chinese: "FRP 配置", italian: "Profilo FRP", french: "Profil FRP", spanish: "Perfil FRP"),
                detail: selectedProfile?.displayName ?? localizedString(language, english: "Create or choose one", chinese: "新建或选择一个配置", italian: "Crea o scegli", french: "Créer ou choisir", spanish: "Crear o elegir"),
                systemImage: "server.rack",
                style: selectedProfile?.enabled == true ? .success : .warning,
                isReady: selectedProfile?.enabled == true
            ),
            TaowaWorkflowStep(
                id: "lan",
                title: localizedString(language, english: "LAN port", chinese: "LAN 端口", italian: "Porta LAN", french: "Port LAN", spanish: "Puerto LAN"),
                detail: parsedLocalPort.map { String($0) } ?? localizedString(language, english: "Detect after opening to LAN", chinese: "对局域网开放后检测", italian: "Rileva dopo apertura LAN", french: "Détecter après ouverture LAN", spanish: "Detectar tras abrir LAN"),
                systemImage: "number",
                style: parsedLocalPort == nil ? .warning : (detection?.isDetected == true ? .success : .neutral),
                isReady: parsedLocalPort != nil
            ),
            TaowaWorkflowStep(
                id: "session",
                title: localizedString(language, english: "Tunnel", chinese: "隧道", italian: "Tunnel", french: "Tunnel", spanish: "Túnel"),
                detail: runningSession?.remoteAddress ?? localizedString(language, english: "Start when ready", chinese: "准备好后启动", italian: "Avvia quando pronto", french: "Démarrer quand prêt", spanish: "Iniciar cuando esté listo"),
                systemImage: "link",
                style: runningSession == nil ? .neutral : .running,
                isReady: runningSession != nil
            )
        ]
    }

    static func startRequirements(
        language: AppLanguage,
        selectedProfile: CoreTaowaFrpProfile?,
        parsedLocalPort: Int?,
        detection: CoreTaowaLanPortDetection?,
        runningSession: CoreTaowaSession?
    ) -> [TaowaRequirement] {
        [
            TaowaRequirement(
                id: "profile",
                title: localizedString(language, english: "FRP profile selected", chinese: "已选择 FRP 配置", italian: "Profilo FRP selezionato", french: "Profil FRP sélectionné", spanish: "Perfil FRP seleccionado"),
                state: selectedProfile == nil ? .missing : (selectedProfile?.enabled == true ? .ready : .warning)
            ),
            TaowaRequirement(
                id: "port",
                title: localizedString(language, english: "LAN port entered", chinese: "已填写 LAN 端口", italian: "Porta LAN inserita", french: "Port LAN saisi", spanish: "Puerto LAN introducido"),
                state: parsedLocalPort == nil ? .missing : (detection?.isDetected == true ? .ready : .warning)
            ),
            TaowaRequirement(
                id: "session",
                title: localizedString(language, english: "No running tunnel", chinese: "没有正在运行的隧道", italian: "Nessun tunnel attivo", french: "Aucun tunnel actif", spanish: "Sin túnel activo"),
                state: runningSession == nil ? .ready : .missing
            )
        ]
    }

    static func connectionStateTitle(
        language: AppLanguage,
        runningSession: CoreTaowaSession?,
        displaySession: CoreTaowaSession?
    ) -> String {
        if runningSession != nil {
            return localizedString(language, english: "Running", chinese: "运行中", italian: "In esecuzione", french: "En cours", spanish: "En ejecución")
        }
        if displaySession?.status == "failed" {
            return AppText.failed.localized(language)
        }
        return localizedString(language, english: "Ready", chinese: "就绪", italian: "Pronto", french: "Prêt", spanish: "Listo")
    }

    static func connectionBadgeStyle(
        runningSession: CoreTaowaSession?,
        displaySession: CoreTaowaSession?
    ) -> StatusBadge.Style {
        if runningSession != nil { return .running }
        if displaySession?.status == "failed" { return .error }
        return .neutral
    }
}
