import SwiftUI

struct InstanceJavaRuntimeScanPanel: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var autoDetectJava: Bool
    let scanJava: () -> Void
    let selectRuntime: (JavaRuntimeCandidate) -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Automated Runtime", chinese: "自动运行环境", italian: "Runtime automatico", french: "Runtime automatisé", spanish: "Runtime automatizado"),
                        systemImage: "wand.and.stars"
                    )
                    Spacer()
                    Toggle(
                        localizedString(theme.language, english: "Auto detect", chinese: "自动检测", italian: "Rileva automaticamente", french: "Détection auto", spanish: "Detectar automáticamente"),
                        isOn: $autoDetectJava
                    )
                    .toggleStyle(.checkbox)
                    GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Scan Java", chinese: "扫描 Java", italian: "Scansiona Java", french: "Scanner Java", spanish: "Escanear Java"), action: scanJava)
                }

                Text(viewModel.javaScanStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.discoveredJavaRuntimes.isEmpty {
                    ContentUnavailableView(
                        localizedString(theme.language, english: "No Java runtimes scanned yet", chinese: "尚未扫描到 Java 运行时", italian: "Nessun runtime Java analizzato", french: "Aucun runtime Java analysé", spanish: "No se escanearon runtimes Java"),
                        systemImage: "cup.and.saucer",
                        description: Text(localizedString(theme.language, english: "Panino can scan PATH, macOS JavaVirtualMachines and Homebrew OpenJDK locations through Core.", chinese: "Panino 会通过 Core 扫描 PATH、macOS JavaVirtualMachines 和 Homebrew OpenJDK 位置。", italian: "Panino analizza PATH, JavaVirtualMachines macOS e OpenJDK Homebrew tramite Core.", french: "Panino analyse PATH, JavaVirtualMachines macOS et OpenJDK Homebrew via Core.", spanish: "Panino escanea PATH, JavaVirtualMachines de macOS y OpenJDK de Homebrew mediante Core."))
                    )
                    .frame(minHeight: 140)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.discoveredJavaRuntimes) { runtime in
                            JavaRuntimeCandidateCard(runtime: runtime, isSelected: viewModel.javaPath == runtime.path) {
                                selectRuntime(runtime)
                            }
                        }
                    }
                }
            }
        }
        .task {
            scanJavaIfNeeded()
        }
    }

    private func scanJavaIfNeeded() {
        if autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
            scanJava()
        }
    }
}

private struct JavaRuntimeCandidateCard: View {
    @EnvironmentObject private var theme: ThemeSettings

    let runtime: JavaRuntimeCandidate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: runtime.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(runtime.isAvailable ? .green : .orange)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(runtime.source)
                        .font(.caption.weight(.semibold))
                    Text(runtime.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(runtime.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.semanticSelectionColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.3),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!runtime.isAvailable)
    }
}
