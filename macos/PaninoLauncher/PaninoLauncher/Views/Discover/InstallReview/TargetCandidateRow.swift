import SwiftUI

struct TargetCandidateRow: View {
    let target: CoreContentTargetCandidate
    let selected: Bool
    let recommended: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(target.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                PlainStatusText(title: statusTitle, style: statusStyle)
            }
            Text([
                "Minecraft \(target.minecraftVersion)",
                target.loader.map { loaderTitle($0) }
            ].compactMap { $0 }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            if let reasonSummary {
                Text(reasonSummary)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(selected ? 0.46 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? theme.semanticSelectionColor.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.28), lineWidth: selected ? 1.5 : 1)
        }
        .help(target.gameDir)
    }

    private var statusTitle: String {
        if target.blockedReasons.isEmpty {
            return selected
                ? localizedString(theme.language, english: "Selected", chinese: "已选择", italian: "Selezionata", french: "Sélectionnée", spanish: "Seleccionada")
                : recommended
                ? localizedString(theme.language, english: "Recommended", chinese: "推荐", italian: "Consigliata", french: "Recommandée", spanish: "Recomendada")
                : localizedString(theme.language, english: "Matched", chinese: "匹配", italian: "Compatibile", french: "Compatible", spanish: "Compatible")
        }
        return localizedString(theme.language, english: "Review", chinese: "需确认", italian: "Verifica", french: "À vérifier", spanish: "Revisar")
    }

    private var statusStyle: StatusBadge.Style {
        target.blockedReasons.isEmpty ? .success : .warning
    }

    private var reasonSummary: String? {
        let reasons = target.blockedReasons.filter { !$0.localizedCaseInsensitiveContains("minecraft_version_mismatch") }
        guard !reasons.isEmpty else { return nil }
        return reasons.joined(separator: ", ")
    }

    private func loaderTitle(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "fabric": return "Fabric"
        case "quilt": return "Quilt"
        case "forge": return "Forge"
        case "neoforge": return "NeoForge"
        default: return rawValue
        }
    }
}
