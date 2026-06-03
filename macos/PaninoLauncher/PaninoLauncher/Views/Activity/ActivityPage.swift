import SwiftUI

struct ActivityPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @State private var showDiagnostics = false

    var body: some View {
        TasksPage(viewModel: viewModel, openDiagnostics: { showDiagnostics = true })
        .sheet(isPresented: $showDiagnostics) {
            LogsPage(viewModel: viewModel)
                .environmentObject(theme)
        }
        .onAppear {
            if appActions.lastCommand == .openLogs {
                showDiagnostics = true
            }
        }
        .onChange(of: appActions.commandSequence) {
            switch appActions.lastCommand {
            case .openLogs:
                showDiagnostics = true
            default:
                break
            }
        }
    }
}
