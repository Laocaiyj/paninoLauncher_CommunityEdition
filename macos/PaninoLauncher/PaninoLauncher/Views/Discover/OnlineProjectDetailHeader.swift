import SwiftUI

struct ProjectImmersiveHeader: View {
    let project: OnlineProject
    var presentation: OnlineProjectDetailPresentation = .full

    @State private var selectedImageIndex = 0
    @EnvironmentObject private var theme: ThemeSettings

    private var heroHeight: CGFloat {
        presentation == .inspector ? 228 : 330
    }

    private var iconSize: CGFloat {
        presentation == .inspector ? 50 : 68
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroMedia

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.44),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                headerChrome
                Spacer(minLength: 18)
                bottomContent
            }
            .padding(presentation == .inspector ? 16 : 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.panel, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(presentation == .inspector ? 0.12 : 0.20), radius: presentation == .inspector ? 18 : 28, x: 0, y: presentation == .inspector ? 8 : 14)
        .onChange(of: project.id) { _, _ in
            selectedImageIndex = 0
        }
        .onChange(of: project.galleryURLs) { _, galleryURLs in
            guard selectedImageIndex >= galleryURLs.count else { return }
            selectedImageIndex = 0
        }
        .accessibilityElement(children: .contain)
    }

    private var headerChrome: some View {
        HStack(alignment: .top, spacing: 10) {
            projectPills
            Spacer(minLength: 12)
            projectLink
        }
    }

    private var bottomContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 18) {
                titleCluster
                Spacer(minLength: 18)
                thumbnailRail
            }

            VStack(alignment: .leading, spacing: 12) {
                titleCluster
                thumbnailRail
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .bottom, spacing: presentation == .inspector ? 11 : 15) {
            OnlineProjectIcon(url: project.iconURL)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: presentation == .inspector ? 4 : 6) {
                Text(project.title)
                    .font(presentation == .inspector ? .title3.bold() : .largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

                Text(projectSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(project.summary)
                    .font(presentation == .inspector ? .caption : .callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(presentation == .inspector ? 2 : 3)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(maxWidth: presentation == .inspector ? .infinity : 720, alignment: .leading)
    }

    @ViewBuilder
    private var heroMedia: some View {
        GeometryReader { proxy in
            if let selectedMediaURL {
                AsyncImage(url: selectedMediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    case .failure:
                        fallbackMedia
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    default:
                        fallbackMedia
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                    }
                }
            } else {
                fallbackMedia
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var fallbackMedia: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.semanticSelectionColor.opacity(0.72),
                    theme.semanticSelectionColor.opacity(0.34),
                    Color(nsColor: .windowBackgroundColor).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            OnlineProjectIcon(url: project.iconURL)
                .frame(width: presentation == .inspector ? 112 : 160, height: presentation == .inspector ? 112 : 160)
                .opacity(0.22)
                .blur(radius: 1.2)
                .offset(x: presentation == .inspector ? 120 : 260, y: presentation == .inspector ? -20 : -36)
        }
    }

    private var projectPills: some View {
        HStack(spacing: 8) {
            ProjectHeroPill(text: project.source.displayName)
            ProjectHeroPill(text: project.projectType.displayTitle)
        }
    }

    @ViewBuilder
    private var thumbnailRail: some View {
        if !project.galleryURLs.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(project.galleryURLs.prefix(4).enumerated()), id: \.element) { index, url in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        ProjectHeroThumbnail(url: url, isSelected: index == selectedImageIndex)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Image \(index + 1)")
                }
            }
            .padding(6)
            .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
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

    private var selectedMediaURL: URL? {
        guard !project.galleryURLs.isEmpty else { return nil }
        return project.galleryURLs[min(selectedImageIndex, project.galleryURLs.count - 1)]
    }

    private var projectSubtitle: String {
        [
            project.authors.prefix(2).joined(separator: ", "),
            project.source.displayName,
            project.projectType.displayTitle
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
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

private struct ProjectHeroThumbnail: View {
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
