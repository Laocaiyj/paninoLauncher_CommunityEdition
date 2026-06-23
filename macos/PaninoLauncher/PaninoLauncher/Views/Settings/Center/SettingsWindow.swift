import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var viewModel: LauncherViewModel

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @State private var selectedSection: PaninoSettingsSection = .account

    var body: some View {
        SettingsCenterPage(viewModel: viewModel, selectedSection: $selectedSection)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(theme.semanticSelectionColor)
        .controlSize(theme.fontDensity.controlSize)
        .preferredColorScheme(theme.appearance.colorScheme)
        .dynamicTypeSize(.xSmall ... .accessibility3)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            selectedSection = appActions.requestedSettingsSection
        }
        .onChange(of: appActions.settingsSectionSequence) {
            selectedSection = appActions.requestedSettingsSection
        }
    }
}
