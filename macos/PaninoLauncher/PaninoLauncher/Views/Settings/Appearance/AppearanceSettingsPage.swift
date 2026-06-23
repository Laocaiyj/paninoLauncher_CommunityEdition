import SwiftUI

struct AppearanceSettingsPage: View {
    var showLanguage = true

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isImportingBackground = false
    @State private var backgroundImportError: String?

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing + 4) {
                PanelHeader(title: AppText.appearance.localized(theme.language), systemImage: "paintbrush")
                AppearancePresetsSection(showLanguage: showLanguage)
                AppearanceAccentSection(customAccentBinding: customAccentBinding)
                AppearanceLiquidGlassSection()
                AppearanceBackgroundSection(isImportingBackground: $isImportingBackground)
                AppearanceLayoutSection()
                AppearanceLegibilitySection()
            }
        }
        .fileImporter(
            isPresented: $isImportingBackground,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                do {
                    theme.customImageBookmark = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    theme.customImagePath = url.path
                    theme.backgroundMode = .customImage
                } catch {
                    theme.customImageBookmark = nil
                    backgroundImportError = error.localizedDescription
                }
            }
        }
        .alert(
            "Background Import Failed",
            isPresented: Binding(
                get: { backgroundImportError != nil },
                set: { if !$0 { backgroundImportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backgroundImportError ?? "")
        }
    }

    private var customAccentBinding: Binding<Color> {
        Binding(
            get: { Color.paninoHex(theme.customAccentHex, fallback: theme.semanticSelectionColor) },
            set: { color in
                if let hex = color.paninoHexString {
                    theme.customAccentHex = hex
                    theme.accent = .custom
                }
            }
        )
    }
}
