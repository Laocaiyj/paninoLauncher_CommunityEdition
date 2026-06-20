import AppKit
import Foundation
import SwiftUI

extension OnlineProjectType {
    var displayTitle: String {
        switch self {
        case .mod:
            return "Mod"
        case .modpack:
            return "Modpack"
        case .resourcePack:
            return "Resource Pack"
        case .shaderPack:
            return "Shader Pack"
        case .plugin:
            return "Plugin"
        case .minecraftVersion:
            return "Minecraft"
        case .loader:
            return "Loader"
        }
    }
}

struct OnlineProjectResultRow: View {
    let project: OnlineProject
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Capsule()
                    .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
                    .frame(width: 3, height: 42)

                OnlineProjectIcon(url: project.iconURL)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(project.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        if !project.authors.isEmpty {
                            Text(project.authors.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(project.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    MetadataLine(items: compactMetadata, font: .caption2)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(projectMeta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 170, alignment: .trailing)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.compactResultRowHeight, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.72) : Color(nsColor: .separatorColor).opacity(isHovering ? 0.55 : 0.28), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isHovering && !reduceMotion ? 1.006 : 1, anchor: .center)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                isHovering = hovering
            }
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.14)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.38 : 0.22)
    }

    private var projectMeta: String {
        let updated = project.updatedAt?.formatted(date: .abbreviated, time: .omitted)
        return [
            "\(project.downloads.formatted()) ↓",
            updated.map { "Updated \($0)" },
            project.source.displayName
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private var compactMetadata: [String] {
        [
            project.projectType.displayTitle,
            project.loaders.prefix(3).map(\.displayTitle).joined(separator: ", "),
            project.categories.prefix(3).joined(separator: ", "),
            project.gameVersions.prefix(3).joined(separator: ", ")
        ]
        .filter { !$0.isEmpty }
    }
}

struct OnlineProjectCard: View {
    let project: OnlineProject
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    OnlineProjectIcon(url: project.iconURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(project.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                MetadataLine(items: [project.source.displayName, project.projectType.displayTitle])

                Text(projectMeta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                MetadataLine(items: [
                    project.loaders.prefix(3).map(\.displayTitle).joined(separator: ", "),
                    project.gameVersions.prefix(2).joined(separator: ", ")
                ], font: .caption2)

                HStack(spacing: 6) {
                    PlainStatusText(title: project.clientSide.sideTitle(prefix: "Client"), style: project.clientSide.badgeStyle)
                    PlainStatusText(title: project.serverSide.sideTitle(prefix: "Server"), style: project.serverSide.badgeStyle)
                }

            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(isSelected ? 0.58 : 0.36), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var projectMeta: String {
        let authors = project.authors.prefix(2).joined(separator: ", ")
        let updated = project.updatedAt?.formatted(date: .abbreviated, time: .omitted)
        return [
            authors.isEmpty ? nil : authors,
            "\(project.downloads.formatted()) downloads",
            updated.map { "Updated \($0)" }
        ].compactMap { $0 }.joined(separator: " · ")
    }
}
