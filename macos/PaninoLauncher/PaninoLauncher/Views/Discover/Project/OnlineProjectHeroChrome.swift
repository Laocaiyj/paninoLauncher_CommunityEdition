import SwiftUI

struct ProjectHeroChrome: View {
    let project: OnlineProject
    let presentation: OnlineProjectDetailPresentation

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 8) {
                ProjectHeroPill(text: project.source.displayName)
                ProjectHeroPill(text: project.projectType.displayTitle)
            }
            Spacer(minLength: 12)
            projectLink
        }
    }

    @ViewBuilder
    private var projectLink: some View {
        if let projectURL = project.projectURL {
            Link(destination: projectURL) {
                if presentation == .inspector {
                    projectLinkLabel
                        .labelStyle(.iconOnly)
                } else {
                    projectLinkLabel
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, presentation == .inspector ? 10 : 12)
            .frame(height: 34)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var projectLinkLabel: some View {
        Label(
            localizedString(theme.language, english: "Open Page", chinese: "打开页面", italian: "Apri pagina", french: "Ouvrir la page", spanish: "Abrir página"),
            systemImage: "safari"
        )
    }
}

private struct ProjectHeroPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.black.opacity(0.24), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }
}

struct ProjectHeroThumbnail: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            default:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.22), lineWidth: isSelected ? 2 : 1)
        }
        .opacity(isSelected ? 1 : 0.78)
    }
}
