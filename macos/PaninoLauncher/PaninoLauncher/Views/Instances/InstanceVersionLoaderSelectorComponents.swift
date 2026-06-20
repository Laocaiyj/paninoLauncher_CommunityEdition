import SwiftUI

struct InstanceVersionSummaryBlock: View {
    let minecraftVersion: String
    let statusTitle: String
    let isInstalled: Bool
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString(theme.language, english: "Minecraft", chinese: "Minecraft", italian: "Minecraft", french: "Minecraft", spanish: "Minecraft"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(minecraftVersion)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(width: 180, alignment: .leading)
                .frame(minHeight: PaninoTokens.Layout.controlMinSize)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
            StatusBadge(title: statusTitle, style: isInstalled ? .success : .download)
        }
    }
}

struct LoaderFamilyPickerBlock: View {
    let selection: Binding<LoaderKind?>
    let availableOptions: [LoaderCompatibilityOption]
    let unavailableOptions: [LoaderCompatibilityOption]
    let isLoading: Bool
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loader")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Loader", selection: selection) {
                Text("Vanilla").tag(nil as LoaderKind?)
                ForEach(availableOptions) { option in
                    Text(option.kind.title).tag(Optional(option.kind))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 430)
            .disabled(isLoading || availableOptions.isEmpty)

            if !unavailableOptions.isEmpty {
                UnavailableLoaderBadges(options: unavailableOptions)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct UnavailableLoaderBadges: View {
    let options: [LoaderCompatibilityOption]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                Text(option.kind.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: Capsule())
                    .help(option.reason ?? "Core marked this Loader unavailable.")
            }
        }
    }
}

struct MinecraftVersionBrowser: View {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    let versions: [MinecraftVersionInfo]
    let selectedVersionID: String
    let selectVersion: (MinecraftVersionInfo) -> () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                PaninoTextInput("Search version", text: $searchText)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(versions) { version in
                            VersionPickerRow(
                                version: version,
                                isSelected: version.id == selectedVersionID,
                                action: selectVersion(version)
                            )
                        }
                    }
                }
                .frame(height: 220)
                .clipped()
            }
            .padding(.top, 8)
        } label: {
            Text(localizedString(theme.language, english: "Browse more versions", chinese: "浏览更多版本", italian: "Sfoglia altre versioni", french: "Parcourir plus de versions", spanish: "Ver más versiones"))
                .font(.caption.weight(.semibold))
        }
    }
}
