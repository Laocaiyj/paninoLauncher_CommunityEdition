import SwiftUI

extension LaunchInstanceDetailPage {
    var lockfileStatusPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(localizedString(theme.language, english: "Lockfile", chinese: "锁文件", italian: "Lockfile", french: "Lockfile", spanish: "Lockfile"), systemImage: "lock.doc")
                        .font(.headline)
                    Spacer()
                    StatusBadge(title: lockfileStatusTitle, style: lockfileBadgeStyle)
                }
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: "\(currentLockfile?.files.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Drift", chinese: "漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva"), value: "\(lockfileVerify?.lockfileDrift.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), value: lockfileVerify?.repairPlan == nil ? "-" : localizedString(theme.language, english: "Ready", chinese: "可用", italian: "Pronto", french: "Prêt", spanish: "Listo"))
                    LaunchMetric(title: localizedString(theme.language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual"), value: "\(manualChangeCount)")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { lockfileActionButtons }
                    VStack(alignment: .leading, spacing: 10) { lockfileActionButtons }
                }
                if !lockfileStatusMessage.isEmpty {
                    Text(lockfileStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .paninoTruncation(.summary(lines: 2))
                }
            }
        }
    }

    @ViewBuilder
    var lockfileActionButtons: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
            Task { await refreshLockfileState() }
        }
        .disabled(lockfileBusy)
        if lockfileVerify?.repairPlan != nil {
            GlassButton(systemImage: "wrench.and.screwdriver", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
                Task { await prepareLockfileReview(policy: "repair") }
            }
            .disabled(lockfileBusy)
        }
    }

    var lockfileUpdatePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Lockfile Updates", chinese: "锁文件更新", italian: "Aggiornamenti lockfile", french: "Mises à jour lockfile", spanish: "Actualizaciones lockfile"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    updatePolicyButton(policy: "keepLocked", systemImage: "lock", title: localizedString(theme.language, english: "Keep Locked", chinese: "保持锁定", italian: "Mantieni bloccato", french: "Garder verrouillé", spanish: "Mantener fijado"))
                    updatePolicyButton(policy: "updateSelected", systemImage: "checklist.checked", title: localizedString(theme.language, english: "Update Selected", chinese: "只更新选中项", italian: "Aggiorna selezionati", french: "Mettre à jour sélection", spanish: "Actualizar selección"))
                    updatePolicyButton(policy: "updateAllSafe", systemImage: "shield.checkered", title: localizedString(theme.language, english: "Update All Safe", chinese: "安全更新全部", italian: "Aggiorna sicuro", french: "Tout mettre à jour sûr", spanish: "Actualizar seguro"))
                    updatePolicyButton(policy: "relock", systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Relock", chinese: "重新锁定", italian: "Riblocca", french: "Reverrouiller", spanish: "Rebloquear"))
                }
            }
        }
    }

    func updatePolicyButton(policy: String, systemImage: String, title: String) -> some View {
        Button {
            Task { await prepareLockfileReview(policy: policy) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(updatePolicySubtitle(policy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(lockfileBusy)
    }

    var detailMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)]
    }

    var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
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

    @MainActor
    func refreshLockfileState() async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
            currentLockfile = current.lockfile
            if let lockfile = current.lockfile {
                lockfileVerify = try await viewModel.verifyLockfile(CoreLockfileVerifyRequest(targetGameDir: instance.gameDirectory, lockfile: lockfile))
                lockfileStatusMessage = ""
            } else {
                lockfileVerify = nil
                lockfileStatusMessage = localizedString(theme.language, english: "No panino-lock.json exists for this instance.", chinese: "此实例还没有 panino-lock.json。", italian: "Nessun panino-lock.json per questa istanza.", french: "Aucun panino-lock.json pour cette instance.", spanish: "No hay panino-lock.json para esta instancia.")
            }
        } catch {
            lockfileVerify = nil
            lockfileStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    func prepareLockfileReview(policy: String) async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            if currentLockfile == nil {
                let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
                currentLockfile = current.lockfile
            }
            let request = CoreLockfileSolveRequest(
                mode: policy == "repair" ? "repair" : "update",
                targetGameDir: instance.gameDirectory,
                minecraftVersion: instance.contentMinecraftVersion,
                loader: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                existingLockfile: currentLockfile,
                updatePolicy: policy
            )
            let result = try await viewModel.solveLockfile(request)
            pendingLockfileReview = PendingLockfileReview(policy: policy, result: result)
            lockfileStatusMessage = ""
        } catch {
            lockfileStatusMessage = error.localizedDescription
        }
    }

    func applyLockfileReview(_ review: PendingLockfileReview) {
        guard let lockfile = review.result.lockfile else { return }
        Task {
            do {
                _ = try await viewModel.applyLockfile(
                    CoreLockfileApplyRequest(
                        targetGameDir: instance.gameDirectory,
                        solverFingerprint: lockfile.fingerprint,
                        result: review.result
                    )
                )
                pendingLockfileReview = nil
                lockfileStatusMessage = localizedString(theme.language, english: "Lockfile applied.", chinese: "锁文件已应用。", italian: "Lockfile applicato.", french: "Lockfile appliqué.", spanish: "Lockfile aplicado.")
                await refreshLockfileState()
            } catch {
                lockfileStatusMessage = error.localizedDescription
            }
        }
    }

    func updatePolicySubtitle(_ policy: String) -> String {
        switch policy {
        case "updateSelected":
            return localizedString(theme.language, english: "Selected packages and required dependencies.", chinese: "选中项目及必需依赖。", italian: "Elementi selezionati e dipendenze.", french: "Sélection et dépendances.", spanish: "Selección y dependencias.")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Compatible updates only.", chinese: "只接受兼容更新。", italian: "Solo aggiornamenti compatibili.", french: "Mises à jour compatibles.", spanish: "Solo compatibles.")
        case "relock":
            return localizedString(theme.language, english: "Resolve from current inputs.", chinese: "按当前输入重新求解。", italian: "Risolvi dagli input attuali.", french: "Résoudre depuis les entrées.", spanish: "Resolver de nuevo.")
        default:
            return localizedString(theme.language, english: "Preserve existing locked packages.", chinese: "保留已锁定内容。", italian: "Mantieni pacchetti bloccati.", french: "Conserver le verrou.", spanish: "Conservar bloqueados.")
        }
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
