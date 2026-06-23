import SwiftUI

struct SettingsCenterPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var selectedSection: PaninoSettingsSection
    let usesInternalScroll: Bool

    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @State var curseForgeAPIKey = ""
    @State var showRuntimeAdvanced = false
    @State var showLocalJava = false
    @State var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @State var pendingLocalJavaDeletion: JavaRuntimeCandidate?
    @State var showAdvancedCore = false
    @State var sourceTestResponse: CoreNetworkSourceTestResponse?
    @State var sourceTestMessage = ""
    @State var sourceTestRunning = false
    @State var speedTestResponse: CoreNetworkSpeedTestResponse?
    @State var speedTestMessage = ""
    @State var speedTestRunning = false

    init(
        viewModel: LauncherViewModel,
        selectedSection: Binding<PaninoSettingsSection> = .constant(.account),
        usesInternalScroll: Bool = true
    ) {
        self.viewModel = viewModel
        self._selectedSection = selectedSection
        self.usesInternalScroll = usesInternalScroll
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PaninoTokens.Layout.sectionSpacing) {
                settingsSidebar
                settingsContentContainer
            }

            VStack(alignment: .leading, spacing: PaninoTokens.Layout.sectionSpacing) {
                settingsSectionPicker
                settingsContentContainer
            }
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete managed Java runtime?", chinese: "删除托管 Java Runtime？", italian: "Eliminare il runtime Java gestito?", french: "Supprimer le runtime Java géré ?", spanish: "¿Eliminar el runtime Java gestionado?"),
            isPresented: Binding(
                get: { pendingManagedJavaDeletion != nil },
                set: { if !$0 { pendingManagedJavaDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingManagedJavaDeletion
        ) { runtime in
            Button(AppText.delete.localized(theme.language), role: .destructive) {
                viewModel.deleteManagedJavaRuntime(runtime)
                pendingManagedJavaDeletion = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingManagedJavaDeletion = nil
            }
        } message: { runtime in
            Text(localizedString(
                theme.language,
                english: "Panino will permanently remove \(runtime.displayName). If an instance still references it, Core will block the deletion.",
                chinese: "Panino 将永久删除 \(runtime.displayName)。如果仍有实例引用它，Core 会阻止删除。",
                italian: "Panino rimuoverà definitivamente \(runtime.displayName). Se un'istanza lo usa ancora, Core bloccherà l'eliminazione.",
                french: "Panino supprimera définitivement \(runtime.displayName). Si une instance l'utilise encore, Core bloquera la suppression.",
                spanish: "Panino eliminará permanentemente \(runtime.displayName). Si una instancia aún lo referencia, Core bloqueará la eliminación."
            ))
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete local Java runtime?", chinese: "删除本机 Java Runtime？", italian: "Eliminare il runtime Java locale?", french: "Supprimer le runtime Java local ?", spanish: "¿Eliminar el runtime Java local?"),
            isPresented: Binding(
                get: { pendingLocalJavaDeletion != nil },
                set: { if !$0 { pendingLocalJavaDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingLocalJavaDeletion
        ) { runtime in
            Button(AppText.delete.localized(theme.language), role: .destructive) {
                viewModel.deleteLocalJavaRuntime(runtime)
                pendingLocalJavaDeletion = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingLocalJavaDeletion = nil
            }
        } message: { runtime in
            Text(localizedString(
                theme.language,
                english: "Panino will permanently remove the Java bundle at \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java and Homebrew shims are not deleted.",
                chinese: "Panino 将永久删除 \(runtime.deleteTarget ?? runtime.path) 这个 Java bundle。PATH、/usr/bin/java 和 Homebrew shim 不会被删除。",
                italian: "Panino rimuoverà definitivamente il bundle Java in \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java e shim Homebrew non vengono eliminati.",
                french: "Panino supprimera définitivement le bundle Java dans \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java et les shims Homebrew ne sont pas supprimés.",
                spanish: "Panino eliminará permanentemente el bundle Java en \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java y shims de Homebrew no se eliminan."
            ))
        }
    }

}
