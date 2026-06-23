import SwiftUI

extension InstanceCreationWizard {
    func moveStep(_ delta: Int) {
        guard let index = InstanceCreationStep.allCases.firstIndex(of: step) else { return }
        let nextIndex = min(max(index + delta, 0), InstanceCreationStep.allCases.count - 1)
        step = InstanceCreationStep.allCases[nextIndex]
    }

    func performPrimaryAction() {
        if draft.source == "Import Modpack" {
            if draft.modpackSource == "Online" {
                openModpackImport()
                dismiss()
            } else {
                prepareModpackImportReview()
            }
        } else {
            create(draft)
            dismiss()
        }
    }

    func regenerateNameIfNeeded() {
        guard shouldRegenerateName else { return }
        draft.name = generatedName
        draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
    }

    func normalizeDraftForPurpose() {
        if draft.source == "Mod Configuration" {
            if draft.loader == nil {
                draft.loader = .fabric
            }
        } else {
            draft.loader = nil
            draft.loaderVersion = nil
        }

        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.name == "New Game Configuration" {
            draft.name = generatedName
            draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
        }
    }
}
