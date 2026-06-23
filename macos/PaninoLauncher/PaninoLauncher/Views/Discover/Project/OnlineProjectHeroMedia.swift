import SwiftUI

struct ProjectHeroMedia: View {
    let project: OnlineProject
    let presentation: OnlineProjectDetailPresentation
    let selectedMediaURL: URL?

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
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
}
