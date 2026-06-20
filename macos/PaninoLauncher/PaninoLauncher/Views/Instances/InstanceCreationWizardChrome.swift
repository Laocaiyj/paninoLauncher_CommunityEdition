import SwiftUI

struct InstanceCreationWizardHeader: View {
    let stepTitle: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack {
            PanelHeader(
                title: localizedString(theme.language, english: "Create Game Configuration", chinese: "创建游戏配置", italian: "Crea configurazione", french: "Créer une configuration", spanish: "Crear configuración"),
                systemImage: "plus.square.on.square"
            )
            Spacer()
            StatusBadge(title: stepTitle, style: .download)
        }
    }
}

struct InstanceCreationWizardFooter: View {
    let step: InstanceCreationStep
    let primaryActionIcon: String
    let primaryActionTitle: String
    let canMoveNext: Bool
    let canComplete: Bool
    let onCancel: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onComplete: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack {
            GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language), action: onCancel)
            Spacer()
            GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back", chinese: "上一步", italian: "Indietro", french: "Retour", spanish: "Atrás"), action: onBack)
                .disabled(step == .source)
            if step == .review {
                GlassButton(systemImage: primaryActionIcon, title: primaryActionTitle, prominent: true, action: onComplete)
                    .disabled(!canComplete)
            } else {
                GlassButton(systemImage: "chevron.right", title: localizedString(theme.language, english: "Next", chinese: "下一步", italian: "Avanti", french: "Suivant", spanish: "Siguiente"), prominent: true, action: onNext)
                    .disabled(!canMoveNext)
            }
        }
    }
}

struct InstanceModpackImportReviewSheet: View {
    let review: PendingModpackImportReview
    let draftName: String
    let onCancel: () -> Void
    let onRepair: () -> Void
    let onConfirm: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InstallPlanReviewSheet(
            plan: review.plan,
            title: localizedString(theme.language, english: "Review modpack import", chinese: "确认整合包导入", italian: "Controlla import modpack", french: "Vérifier import modpack", spanish: "Revisar importación"),
            subtitle: draftName,
            confirmTitle: localizedString(theme.language, english: "Import", chinese: "导入", italian: "Importa", french: "Importer", spanish: "Importar"),
            repairTitle: repairTitle,
            onCancel: onCancel,
            onRepair: onRepair,
            onConfirm: onConfirm
        )
    }

    private var repairTitle: String? {
        guard review.plan.status == "blocked" || !review.plan.blockedReasons.isEmpty else { return nil }
        return localizedString(theme.language, english: "Run Preflight", chinese: "重新预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")
    }
}
