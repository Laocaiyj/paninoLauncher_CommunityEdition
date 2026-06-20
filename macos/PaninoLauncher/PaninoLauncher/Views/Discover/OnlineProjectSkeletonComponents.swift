import AppKit
import SwiftUI

struct OnlineProjectSkeletonGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 282), spacing: 12)], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.2)).frame(width: 42, height: 42)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.2)).frame(height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.14)).frame(height: 42)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.16)).frame(width: 150, height: 14)
                }
                .padding(12)
                .frame(minHeight: 132)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                .redacted(reason: .placeholder)
            }
        }
    }
}

struct OnlineProjectSkeletonList: View {
    var body: some View {
        LazyVStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 180, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.14))
                            .frame(height: 12)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.16))
                        .frame(width: 88, height: 22)
                }
                .padding(10)
                .frame(minHeight: PaninoTokens.Layout.compactResultRowHeight)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                .redacted(reason: .placeholder)
            }
        }
    }
}
