import SwiftUI

struct JavaRuntimePolicySelector: View {
    @Binding var javaPath: String
    let managedRuntimes: [CoreJavaManagedRuntime]
    let localRuntimes: [JavaRuntimeCandidate]
    var showCustomPath = true

    @EnvironmentObject var theme: ThemeSettings
    @State var wantsCustomPath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(options) { option in
                    Button(option.title) {
                        applySelection(option.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 300, alignment: .leading)

            Text(selectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if selectedKey == "custom" && showCustomPath {
                PaninoTextInput("java or /path/to/java", text: $javaPath)
                    .frame(maxWidth: 520)
            }
        }
    }
}

struct ManagedJavaRuntimeRow: View {
    let runtime: CoreJavaManagedRuntime
    let makeDefault: () -> Void
    let verify: () -> Void
    let remove: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(runtime.displayName)
                    .font(.callout.weight(.semibold))
                Text(runtime.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let lastVerifiedAt = runtime.lastVerifiedAt {
                    Text(localizedString(theme.language, english: "Verified \(lastVerifiedAt.formatted(date: .abbreviated, time: .shortened))", chinese: "校验于 \(lastVerifiedAt.formatted(date: .abbreviated, time: .shortened))", italian: "Verificato \(lastVerifiedAt.formatted(date: .abbreviated, time: .shortened))", french: "Vérifié \(lastVerifiedAt.formatted(date: .abbreviated, time: .shortened))", spanish: "Verificado \(lastVerifiedAt.formatted(date: .abbreviated, time: .shortened))"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Default", chinese: "设为默认", italian: "Predefinito", french: "Par défaut", spanish: "Predeterminado"), action: makeDefault)
            GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Verify", chinese: "校验", italian: "Verifica", french: "Vérifier", spanish: "Verificar"), action: verify)
            GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: remove)
                .disabled(runtime.usedByInstanceCount > 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}
