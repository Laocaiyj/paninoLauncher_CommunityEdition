import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
    @ViewBuilder
    var categoryChips: some View {
        if !categoryOptions.isEmpty {
            let tokens = theme.resolvedTokens(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString(theme.language, english: "Intent", chinese: "内容意图", italian: "Intento", french: "Intention", spanish: "Intención"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    categoryFilterButton(
                        title: localizedString(theme.language, english: "All", chinese: "全部", italian: "Tutti", french: "Tout", spanish: "Todo"),
                        isSelected: selectedCategory == nil
                    ) {
                        selectCategory(nil)
                    }
                    ForEach(primaryCategoryOptions) { category in
                        categoryFilterButton(title: category.title(language: theme.language), isSelected: selectedCategory == category.id) {
                            selectCategory(category.id)
                        }
                    }
                    if !overflowCategoryOptions.isEmpty {
                        Menu {
                            ForEach(overflowCategoryOptions) { category in
                                Button(category.title(language: theme.language)) {
                                    selectCategory(category.id)
                                }
                            }
                        } label: {
                            Label(localizedString(theme.language, english: "More", chinese: "更多", italian: "Altro", french: "Plus", spanish: "Más"), systemImage: "ellipsis")
                        }
                        .menuStyle(.button)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 32)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius + 4, style: .continuous)
                        .fill(Color.clear)
                        .paninoGlassSurface(
                            tokens: tokens,
                            level: .panel,
                            cornerRadius: tokens.controlCornerRadius + 4,
                            interactive: true
                        )
                        .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.24))
                        .paninoDepthOverlay(tokens: tokens, level: .panel, cornerRadius: tokens.controlCornerRadius + 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius + 4, style: .continuous)
                        .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity * 0.46), lineWidth: tokens.strokeWidth)
                }
            }
        }
    }

    func categoryFilterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion || theme.reducesInterfaceMotion
        )
        return Button(action: action) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
                    .frame(width: 3, height: 16)
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 132, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? theme.semanticSelectionColor.opacity(0.18)
                            : Color(nsColor: .controlBackgroundColor).opacity(0.10)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? tokens.depthHighlightOpacity * 1.30 : tokens.depthHighlightOpacity * 0.58),
                                        Color.clear,
                                        Color.black.opacity(isSelected ? tokens.depthShadeOpacity * 0.70 : tokens.depthShadeOpacity * 0.36)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isSelected
                            ? theme.semanticSelectionColor.opacity(0.70)
                            : Color(nsColor: .separatorColor).opacity(0.28),
                        lineWidth: 1
                    )
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
