import SwiftUI

struct JavaRuntimePolicySelector: View {
    @Binding var javaPath: String
    let managedRuntimes: [CoreJavaManagedRuntime]
    let localRuntimes: [JavaRuntimeCandidate]
    var showCustomPath = true

    @EnvironmentObject private var theme: ThemeSettings
    @State private var wantsCustomPath = false

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

    private var selectedKey: String {
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return wantsCustomPath ? "custom" : "auto" }
        if let runtime = managedRuntimes.first(where: { samePath($0.javaExecutable, trimmed) }) {
            return managedKey(runtime.id)
        }
        if let runtime = localRuntimes.first(where: { samePath($0.path, trimmed) }) {
            return localKey(runtime.path)
        }
        return "custom"
    }

    private var selectedTitle: String {
        options.first(where: { $0.id == selectedKey })?.title
            ?? localizedString(theme.language, english: "Custom path", chinese: "自定义路径", italian: "Percorso personalizzato", french: "Chemin personnalisé", spanish: "Ruta personalizada")
    }

    private var selectionSummary: String {
        if let option = options.first(where: { $0.id == selectedKey }) {
            return option.detail
        }
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? customPathHint : trimmed
    }

    private var options: [JavaRuntimePolicyOption] {
        var values = [
            JavaRuntimePolicyOption(
                id: "auto",
                title: localizedString(theme.language, english: "Automatic", chinese: "自动", italian: "Automatico", french: "Automatique", spanish: "Automático"),
                detail: automaticDetail
            )
        ]

        values += managedRuntimes.map { runtime in
            JavaRuntimePolicyOption(
                id: managedKey(runtime.id),
                title: "\(runtime.displayName) · Panino",
                detail: runtime.detailText
            )
        }

        values += localRuntimes.filter(\.isAvailable).map { runtime in
            JavaRuntimePolicyOption(
                id: localKey(runtime.path),
                title: runtime.source,
                detail: runtime.displayText
            )
        }

        if showCustomPath {
            values.append(
                JavaRuntimePolicyOption(
                    id: "custom",
                    title: localizedString(theme.language, english: "Custom path", chinese: "自定义路径", italian: "Percorso personalizzato", french: "Chemin personnalisé", spanish: "Ruta personalizada"),
                    detail: customPathHint
                )
            )
        }
        return values
    }

    private var automaticDetail: String {
        localizedString(
            theme.language,
            english: "Panino chooses Java from the Minecraft manifest and downloads it when needed.",
            chinese: "Panino 会按 Minecraft 清单自动选择 Java，并在缺失时下载。",
            italian: "Panino sceglie Java dal manifest Minecraft e lo scarica se manca.",
            french: "Panino choisit Java depuis le manifeste Minecraft et le télécharge si nécessaire.",
            spanish: "Panino elige Java desde el manifiesto de Minecraft y lo descarga si falta."
        )
    }

    private var customPathHint: String {
        localizedString(theme.language, english: "Enter a Java executable path.", chinese: "填写 Java 可执行文件路径。", italian: "Inserisci il percorso Java.", french: "Saisissez le chemin Java.", spanish: "Introduce la ruta de Java.")
    }

    private func applySelection(_ key: String) {
        if key == "auto" {
            wantsCustomPath = false
            javaPath = ""
            return
        }
        if key == "custom" {
            wantsCustomPath = true
            return
        }
        if key.hasPrefix("managed:"),
           let runtime = managedRuntimes.first(where: { managedKey($0.id) == key }) {
            wantsCustomPath = false
            javaPath = runtime.javaExecutable
            return
        }
        if key.hasPrefix("local:"),
           let runtime = localRuntimes.first(where: { localKey($0.path) == key }) {
            wantsCustomPath = false
            javaPath = runtime.path
        }
    }

    private func managedKey(_ id: String) -> String {
        "managed:\(id)"
    }

    private func localKey(_ path: String) -> String {
        "local:\(path)"
    }

    private func samePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}

private struct JavaRuntimePolicyOption: Identifiable {
    let id: String
    let title: String
    let detail: String
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
