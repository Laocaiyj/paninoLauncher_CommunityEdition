import SwiftUI

extension LaunchInstanceDetailPage {
    var lockfileStatusPanel: some View {
        LaunchLockfileStatusPanel(
            language: theme.language,
            fileCount: currentLockfile?.files.count ?? 0,
            driftCount: lockfileVerify?.lockfileDrift.count ?? 0,
            repairReady: lockfileVerify?.repairPlan != nil,
            manualChangeCount: manualChangeCount,
            statusTitle: lockfileStatusTitle,
            badgeStyle: lockfileBadgeStyle,
            statusMessage: lockfileStatusMessage,
            busy: lockfileBusy,
            onRefresh: refreshLockfileFromPanel,
            onRepair: prepareLockfileRepairReview
        )
    }

    var lockfileUpdatePanel: some View {
        LaunchLockfileUpdatePanel(
            language: theme.language,
            busy: lockfileBusy,
            onPolicySelected: prepareLockfileUpdateReview
        )
    }

    var manualChangeCount: Int {
        guard let lockfileVerify else { return 0 }
        return lockfileVerify.manualFiles.count + lockfileVerify.extraFiles.count
    }

    var lockfileStatusTitle: String {
        if lockfileBusy {
            return localizedString(theme.language, english: "Checking", chinese: "检查中", italian: "Controllo", french: "Vérification", spanish: "Comprobando")
        }
        if needsRelock {
            return localizedString(theme.language, english: "Needs Relock", chinese: "需要重解", italian: "Da ribloccare", french: "À reverrouiller", spanish: "Rebloquear")
        }
        guard let lockfileVerify else {
            return currentLockfile == nil
                ? localizedString(theme.language, english: "No Lock", chinese: "未锁定", italian: "Nessun lock", french: "Non verrouillé", spanish: "Sin lock")
                : localizedString(theme.language, english: "Unknown", chinese: "未知", italian: "Sconosciuto", french: "Inconnu", spanish: "Desconocido")
        }
        if lockfileVerify.repairPlan != nil {
            return localizedString(theme.language, english: "Repairable", chinese: "可修复", italian: "Riparabile", french: "Réparable", spanish: "Reparable")
        }
        if manualChangeCount > 0 {
            return localizedString(theme.language, english: "Manual Changes", chinese: "手动修改", italian: "Modifiche manuali", french: "Modifications", spanish: "Cambios manuales")
        }
        if lockfileVerify.status == "locked" {
            return localizedString(theme.language, english: "Locked", chinese: "已锁定", italian: "Bloccato", french: "Verrouillé", spanish: "Bloqueado")
        }
        return localizedString(theme.language, english: "Drifted", chinese: "有漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva")
    }

    var lockfileBadgeStyle: StatusBadge.Style {
        if lockfileBusy { return .download }
        if needsRelock || lockfileVerify?.repairPlan != nil { return .warning }
        if manualChangeCount > 0 || lockfileVerify?.status == "drifted" { return .warning }
        return currentLockfile == nil ? .neutral : .success
    }

    var needsRelock: Bool {
        guard let currentLockfile else { return false }
        if let minecraft = currentLockfile.minecraft, minecraft != instance.contentMinecraftVersion {
            return true
        }
        if let family = currentLockfile.loader?.family, family != instance.loader?.rawValue {
            return true
        }
        return false
    }

    func lockfileReviewTitle(for policy: String) -> String {
        switch policy {
        case "repair":
            return localizedString(theme.language, english: "Review repair plan", chinese: "确认修复计划", italian: "Controlla riparazione", french: "Vérifier réparation", spanish: "Revisar reparación")
        case "updateSelected":
            return localizedString(theme.language, english: "Review selected update", chinese: "确认选中更新", italian: "Controlla selezionati", french: "Vérifier sélection", spanish: "Revisar selección")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Review safe update", chinese: "确认安全更新", italian: "Controlla aggiornamento sicuro", french: "Vérifier mise à jour sûre", spanish: "Revisar actualización segura")
        case "relock":
            return localizedString(theme.language, english: "Review relock", chinese: "确认重新锁定", italian: "Controlla riblocco", french: "Vérifier reverrouillage", spanish: "Revisar rebloqueo")
        default:
            return localizedString(theme.language, english: "Review lockfile", chinese: "确认锁文件", italian: "Controlla lockfile", french: "Vérifier lockfile", spanish: "Revisar lockfile")
        }
    }

    func lockfileReviewSubtitle(for result: CoreLockfileSolverResult) -> String {
        let changes = result.changeset.add.count + result.changeset.replace.count + result.changeset.remove.count + result.changeset.repair.count
        let deps = result.lockfile?.constraints.filter { $0.required && $0.relation == "requires" }.count ?? 0
        return localizedString(theme.language, english: "\(changes) changes · \(deps) required dependencies", chinese: "\(changes) 个变更 · \(deps) 个必需依赖", italian: "\(changes) cambi · \(deps) dipendenze", french: "\(changes) changements · \(deps) dépendances", spanish: "\(changes) cambios · \(deps) dependencias")
    }
}
