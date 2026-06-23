import SwiftUI

extension LaunchDashboard {
    var launchSummary: String {
        let java = javaResolution(for: selectedInstance)?.conciseStatus
            ?? (selectedInstance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Auto Java" : selectedInstance.javaPath)
        let loader = selectedInstance.loaderTitle(language: theme.language)
        let tuning = selectedInstance.memoryPolicy == .custom
            ? "\(selectedInstance.customMemoryMb ?? selectedInstance.memoryMb) MB"
            : localizedString(theme.language, english: "Auto tuning", chinese: "自动调校", italian: "Tuning auto", french: "Réglage auto", spanish: "Ajuste auto")
        return "Minecraft \(selectedInstance.minecraftVersion) · \(loader) · \(tuning) · \(java)"
    }

    var memoryBinding: Binding<Int> {
        Binding(
            get: { selectedInstance.memoryMb },
            set: { newValue in
                viewModel.memoryMb = newValue
                updateSelectedInstance {
                    $0.memoryPolicy = .custom
                    $0.customMemoryMb = newValue
                    $0.memoryMb = newValue
                }
            }
        )
    }

    var javaBinding: Binding<String> {
        Binding(
            get: { selectedInstance.javaPath },
            set: { newValue in
                viewModel.javaPath = newValue
                updateSelectedInstance { $0.javaPath = newValue }
            }
        )
    }

    var loaderBinding: Binding<LoaderKind?> {
        Binding(
            get: { selectedInstance.loader },
            set: { newValue in
                updateSelectedInstance { $0.loader = newValue }
            }
        )
    }
}
