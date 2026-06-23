import Foundation

extension JvmTuningControl {
    var primaryActionTitle: String {
        if failedWithRollback {
            return localizedString(theme.language, english: "Restore Last Good", chinese: "恢复上次可用设置", italian: "Ripristina funzionante", french: "Restaurer le dernier réglage", spanish: "Restaurar último válido")
        }
        if hasManualOverride {
            return localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动推荐", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático")
        }
        if resolved?.applyMode == "ask" || resolved?.confidence == "estimated" {
            return localizedString(theme.language, english: "Review Estimate", chinese: "确认估算建议", italian: "Rivedi stima", french: "Vérifier l'estimation", spanish: "Revisar estimación")
        }
        return localizedString(theme.language, english: "Apply Recommended", chinese: "应用推荐设置", italian: "Applica consigliato", french: "Appliquer recommandé", spanish: "Aplicar recomendado")
    }

    var primaryActionIcon: String {
        failedWithRollback ? "arrow.uturn.backward.circle" : "wand.and.stars"
    }

    var failedWithRollback: Bool {
        lastSnapshot?.state == .failed && lastKnownGood != nil
    }

    func performPrimaryAction() {
        if let lastKnownGood, failedWithRollback {
            onRestoreLastKnownGood?(lastKnownGood)
            return
        }
        onRestoreAutomatic()
    }

    private var hasManualOverride: Bool {
        memoryPolicy == .custom
            || jvmProfile == .custom
            || !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
