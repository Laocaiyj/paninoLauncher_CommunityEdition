import SwiftUI

struct ProjectImmersiveHeader: View {
    let project: OnlineProject
    var presentation: OnlineProjectDetailPresentation = .full

    @State private var selectedImageIndex = 0

    private var heroHeight: CGFloat {
        presentation == .inspector ? 228 : 330
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ProjectHeroMedia(
                project: project,
                presentation: presentation,
                selectedMediaURL: selectedMediaURL
            )

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
                ProjectHeroChrome(project: project, presentation: presentation)
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

    private var bottomContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 18) {
                ProjectHeroTitleCluster(project: project, presentation: presentation)
                Spacer(minLength: 18)
                thumbnailRail
            }

            VStack(alignment: .leading, spacing: 12) {
                ProjectHeroTitleCluster(project: project, presentation: presentation)
                thumbnailRail
            }
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

    private var selectedMediaURL: URL? {
        guard !project.galleryURLs.isEmpty else { return nil }
        return project.galleryURLs[min(selectedImageIndex, project.galleryURLs.count - 1)]
    }
}
