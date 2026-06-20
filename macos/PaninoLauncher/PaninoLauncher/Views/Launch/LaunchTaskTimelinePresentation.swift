import SwiftUI

enum LaunchTimelineStageState {
    case pending
    case running
    case done
    case failed
    case cancelled

    var style: StatusBadge.Style {
        switch self {
        case .pending:
            return .neutral
        case .running:
            return .running
        case .done:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "circle"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .done:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .cancelled:
            return "pause.circle.fill"
        }
    }
}

struct LaunchTimelineStage: Identifiable {
    let id: String
    let title: String
    let detail: String
    let state: LaunchTimelineStageState
}

struct LaunchTaskTimelinePresentation {
    let task: TaskSnapshot?
    let language: AppLanguage

    var taskBadgeStyle: StatusBadge.Style {
        guard let task else { return .neutral }
        switch task.state {
        case .queued, .running:
            return .running
        case .succeeded:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }

    var stages: [LaunchTimelineStage] {
        let active = activeStageIndex
        return stageDefinitions.enumerated().map { index, definition in
            LaunchTimelineStage(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                state: stateForStage(index: index, active: active)
            )
        }
    }

    func progressValue(record: TaskRecord?) -> Double {
        if let record {
            return min(max(record.progress, 0), 1)
        }
        guard let task else { return 0 }
        switch task.state {
        case .queued:
            return 0.12
        case .running:
            return 0.48
        case .succeeded:
            return 1
        case .failed, .cancelled:
            return 0
        }
    }

    private var stageDefinitions: [(id: String, title: String, detail: String)] {
        [
            ("prepare", localizedString(language, english: "Prepare", chinese: "准备", italian: "Prepara", french: "Préparer", spanish: "Preparar"), localizedString(language, english: "Core, account, Java and directory checks.", chinese: "检查 Core、账号、Java 和目录。", italian: "Controlla Core, account, Java e cartella.", french: "Vérifie Core, compte, Java et dossier.", spanish: "Comprueba Core, cuenta, Java y directorio.")),
            ("install", localizedString(language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"), localizedString(language, english: "Install or repair version and resource files.", chinese: "安装或修复版本与资源文件。", italian: "Installa o ripara versioni e risorse.", french: "Installe ou répare versions et ressources.", spanish: "Instala o repara versiones y recursos.")),
            ("verify", localizedString(language, english: "Verify", chinese: "校验", italian: "Verifica", french: "Vérifier", spanish: "Verificar"), localizedString(language, english: "Check hashes, libraries, assets and natives.", chinese: "校验 hash、库、资源索引和 natives。", italian: "Controlla hash, librerie, asset e native.", french: "Vérifie hashes, bibliothèques, assets et natives.", spanish: "Comprueba hashes, librerías, assets y natives.")),
            ("run", localizedString(language, english: "Run", chinese: "启动", italian: "Avvia", french: "Lancer", spanish: "Ejecutar"), localizedString(language, english: "Start Java and track the game process.", chinese: "启动 Java 并跟踪游戏进程。", italian: "Avvia Java e segue il processo.", french: "Lance Java et suit le processus.", spanish: "Inicia Java y sigue el proceso."))
        ]
    }

    private var activeStageIndex: Int {
        guard let task else { return 0 }
        if let phase = task.diagnostic?.phase.lowercased() {
            if phase == "verify" { return 2 }
            if phase == "launch" || phase == "java" { return 3 }
            if ["download", "loader", "shader", "content", "write"].contains(phase) { return 1 }
            if phase == "prepare" || phase == "preflight" || phase == "solve" || phase == "plan" { return 0 }
        }
        let combined = "\(task.kind) \(task.message ?? "") \(task.errorCode ?? "")".lowercased()
        if combined.contains("hash") || combined.contains("verify") || combined.contains("asset") || combined.contains("library") {
            return 2
        }
        if combined.contains("java") || combined.contains("launch") || combined.contains("process") {
            return 3
        }
        if combined.contains("install") || combined.contains("download") || combined.contains("content") {
            return 1
        }
        return 0
    }

    private func stateForStage(index: Int, active: Int) -> LaunchTimelineStageState {
        guard let task else { return .pending }
        switch task.state {
        case .succeeded:
            return .done
        case .failed:
            if index < active { return .done }
            return index == active ? .failed : .pending
        case .cancelled:
            if index < active { return .done }
            return index == active ? .cancelled : .pending
        case .queued, .running:
            if index < active { return .done }
            return index == active ? .running : .pending
        }
    }
}
