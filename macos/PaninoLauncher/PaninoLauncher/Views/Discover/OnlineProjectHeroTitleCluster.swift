import SwiftUI

struct ProjectHeroTitleCluster: View {
    let project: OnlineProject
    let presentation: OnlineProjectDetailPresentation

    private var iconSize: CGFloat {
        presentation == .inspector ? 50 : 68
    }

    var body: some View {
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
