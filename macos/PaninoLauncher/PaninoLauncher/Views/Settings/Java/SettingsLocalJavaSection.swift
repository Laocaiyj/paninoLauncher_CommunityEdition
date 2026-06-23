import SwiftUI

struct SettingsLocalJavaSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var isExpanded: Bool
    @Binding var pendingLocalJavaDeletion: JavaRuntimeCandidate?

    private var availableRuntimes: [JavaRuntimeCandidate] {
        viewModel.discoveredJavaRuntimes.filter(\.isAvailable)
    }

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(viewModel.javaScanStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac"), action: viewModel.scanJavaRuntimes)
                }
                if availableRuntimes.isEmpty {
                    Text(localizedString(theme.language, english: "No local Java runtime is available yet.", chinese: "尚未发现可用的本机 Java。", italian: "Nessun Java locale disponibile.", french: "Aucun Java local disponible.", spanish: "No hay Java local disponible."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(availableRuntimes) { runtime in
                            SettingsLocalJavaRuntimeRow(
                                runtime: runtime,
                                remove: { pendingLocalJavaDeletion = runtime }
                            )
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(localizedString(theme.language, english: "Local Java", chinese: "本机 Java", italian: "Java locale", french: "Java local", spanish: "Java local"))
                .font(.callout.weight(.semibold))
        }
    }
}

struct SettingsLocalJavaRuntimeRow: View {
    @EnvironmentObject private var theme: ThemeSettings

    let runtime: JavaRuntimeCandidate
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(runtime.source)
                        .font(.caption.weight(.semibold))
                    if runtime.hasMeaningfulSummary {
                        Text(runtime.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(runtime.pathDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let deleteTarget = runtime.deleteTarget, runtime.supportsDeletion {
                    Text(deleteTarget)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if runtime.supportsDeletion {
                GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: remove)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}
