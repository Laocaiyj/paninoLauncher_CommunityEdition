import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.openWindow) var openWindow
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject var performanceCoachStore: PerformanceCoachStore
    @EnvironmentObject var packDoctorStore: PackDoctorStore
    @EnvironmentObject var appActions: AppActionCenter
    @State var notifiedTaskIDs: Set<String> = []
    @State var notifiedExpiredAccountIDs: Set<String> = []
    @State var selectedSection: LauncherSection? = .launch

    var body: some View {
        ZStack {
            LauncherBackground(
                version: viewModel.version,
                isImmersiveEnabled: (selectedSection ?? .launch) == .launch
            )

            VStack(spacing: 0) {
                TopNavigationBar(selection: $selectedSection)

                LauncherHorizontalDivider()

                MainContentView(
                    section: selectedSection ?? .launch,
                    sectionSelection: $selectedSection,
                    viewModel: viewModel
                )
                    .frame(minWidth: PaninoTokens.Window.minimumMainWidth, maxWidth: .infinity)
            }
        }
        .tint(theme.semanticSelectionColor)
        .controlSize(theme.fontDensity.controlSize)
        .preferredColorScheme(theme.appearance.colorScheme)
        .dynamicTypeSize(.xSmall ... .accessibility3)
        .frame(minWidth: PaninoTokens.Window.minimumWidth, minHeight: PaninoTokens.Window.minimumHeight)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            DroppedContentImporter.importItems(
                providers,
                selectedKind: versionStore.selectedAssetKind,
                instance: instanceStore.selectedInstance,
                taskStore: taskCenterStore,
                versionStore: versionStore
            )
        }
        .onAppear {
            NativeMenuLocalizer.apply(language: theme.language)
        }
        .task {
            UserNotificationService.shared.requestAuthorization()
            if launcherSettings.autoConnectCore {
                Task {
                    await viewModel.startCoreIfNeeded()
                }
            }
            Task {
                viewModel.checkJavaRuntime()
            }
            Task {
                await viewModel.restoreAccountIfPossible(accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID)
            }
        }
        .onDisappear {
            Task {
                await viewModel.shutdownCore()
            }
        }
        .onChange(of: theme.language) {
            NativeMenuLocalizer.apply(language: theme.language)
        }
        .onChange(of: appActions.commandSequence) {
            handleNativeCommand(appActions.lastCommand)
        }
        .onChange(of: viewModel.accountState) {
            if let account = viewModel.accountState.account {
                accountStore.upsert(account: account)
                notifyExpiredAccountIfNeeded(account)
            }
        }
        .onChange(of: viewModel.currentTask) {
            taskCenterStore.sync(snapshot: viewModel.currentTask)
            refreshManagedContentAfterTask(viewModel.currentTask)
            notifyTaskIfNeeded(viewModel.currentTask)
        }
        .onChange(of: viewModel.currentTaskProgress) {
            taskCenterStore.apply(progress: viewModel.currentTaskProgress)
        }
        .onChange(of: viewModel.latestCoreEvent) {
            taskCenterStore.applyTaowa(event: viewModel.latestCoreEvent)
        }
        .onChange(of: versionStore.installedInstances) {
            instanceStore.reconcileInstalledInstances(versionStore.installedInstances, settings: launcherSettings)
        }
        .onChange(of: viewModel.coreState) {
            if viewModel.coreState.isReady, let endpoint = viewModel.apiClient?.endpoint {
                performanceCoachStore.configure(endpoint: endpoint)
                packDoctorStore.configure(endpoint: endpoint)
            }
            if case .failed = viewModel.coreState {
                taskCenterStore.markInterrupted(activeTask: viewModel.currentTask)
            }
        }
    }
}
