import SwiftUI

struct LaunchPetPlaceholder: View {
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0 / 30.0)) { timeline in
            let seconds = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let state = PixelOctocatState(seconds: seconds)
            ZStack {
                RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.30))
                PixelOctocatMascot(state: state)
                    .offset(x: state.driftX, y: state.floatY)
                accentIdlePixels(seconds: seconds)
            }
            .frame(width: 86, height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        }
        .accessibilityLabel("Pixel Octocat mascot pet")
    }

    @ViewBuilder
    private func accentIdlePixels(seconds: TimeInterval) -> some View {
        GeometryReader { proxy in
            let pixel = min(proxy.size.width / 24, proxy.size.height / 16)
            let pulse = (sin(seconds * 3.2) + 1) / 2
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(theme.semanticSelectionColor.opacity(0.18 + 0.24 * pulse))
                    .frame(width: pixel, height: pixel)
                    .offset(x: pixel * 18, y: pixel * 2)
                Rectangle()
                    .fill(theme.semanticSelectionColor.opacity(0.12 + 0.18 * pulse))
                    .frame(width: pixel, height: pixel)
                    .offset(x: pixel * 20, y: pixel * 1)
            }
        }
        .allowsHitTesting(false)
    }
}
