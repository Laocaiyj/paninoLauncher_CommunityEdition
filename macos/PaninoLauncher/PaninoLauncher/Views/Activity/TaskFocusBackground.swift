import SwiftUI

struct TaskFocusBackground: View {
    let record: TaskRecord?
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                TaskFocusDarkTexture(statusColor: statusColor)
                    .opacity(record?.state.isActive == true ? 0.98 : 1)

                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: proxy.size.width * 0.44, height: proxy.size.width * 0.44)
                    .blur(radius: 44)
                    .offset(x: proxy.size.width * 0.28, y: -proxy.size.height * 0.30)

                Circle()
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1.5)
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.width * 0.58)
                    .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.24)

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.black.opacity(0.060 - Double(index) * 0.004))
                            .frame(width: proxy.size.width * CGFloat(0.88 - Double(index) * 0.10), height: 5)
                    }
                }
                .rotationEffect(.degrees(-10))
                .offset(x: -proxy.size.width * 0.16, y: proxy.size.height * 0.10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var statusColor: Color {
        record?.state.badgeStyle.color ?? theme.semanticSelectionColor
    }

    private var backgroundColors: [Color] {
        let base = statusColor
        if record?.state.needsAttention == true {
            return [base.opacity(0.56), Color.orange.opacity(0.28), Color(nsColor: .windowBackgroundColor).opacity(0.70)]
        }
        if record?.state.isActive == true {
            return [base.opacity(0.58), theme.semanticSelectionColor.opacity(0.36), Color(nsColor: .windowBackgroundColor).opacity(0.70)]
        }
        return [theme.semanticSelectionColor.opacity(0.40), Color(nsColor: .controlBackgroundColor).opacity(0.44), Color(nsColor: .windowBackgroundColor).opacity(0.76)]
    }
}

private struct TaskFocusDarkTexture: View {
    let statusColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.24),
                        statusColor.opacity(0.024),
                        Color.black.opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.06),
                        Color.black.opacity(0.30),
                        Color.black.opacity(0.58)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.058 - Double(index) * 0.004))
                        .frame(
                            width: proxy.size.width * CGFloat(0.72 - Double(index) * 0.050),
                            height: 18
                        )
                        .offset(
                            x: -proxy.size.width * CGFloat(0.20 - Double(index) * 0.050),
                            y: proxy.size.height * CGFloat(0.16 + Double(index) * 0.085)
                        )
                }
                .rotationEffect(.degrees(-9))

                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.black.opacity(0.040 - Double(index) * 0.003))
                        .frame(
                            width: proxy.size.width * CGFloat(0.76 - Double(index) * 0.055),
                            height: 3
                        )
                        .offset(
                            x: -proxy.size.width * CGFloat(0.18 - Double(index) * 0.045),
                            y: proxy.size.height * CGFloat(0.08 + Double(index) * 0.070)
                        )
                }
                .rotationEffect(.degrees(-9))

                Circle()
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1.1)
                    .frame(width: proxy.size.width * 0.46, height: proxy.size.width * 0.46)
                    .offset(x: proxy.size.width * 0.18, y: -proxy.size.height * 0.34)

                Circle()
                    .strokeBorder(Color.black.opacity(0.045), lineWidth: 1)
                    .frame(width: proxy.size.width * 0.66, height: proxy.size.width * 0.66)
                    .offset(x: proxy.size.width * 0.22, y: -proxy.size.height * 0.28)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}
