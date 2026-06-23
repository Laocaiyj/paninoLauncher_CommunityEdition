import SwiftUI

struct LockfileAdvancedSection: View {
    let result: CoreLockfileSolverResult
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text("fingerprint: \(result.lockfile?.fingerprint ?? result.typedPlan.fingerprint)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                ForEach(result.typedPlan.nodes.prefix(18), id: \.id) { node in
                    LockfileNodeRow(node: node)
                }
                if result.typedPlan.nodes.count > 18 {
                    Text(moreNodesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(
                localizedString(theme.language, english: "Advanced lockfile", chinese: "高级锁文件", italian: "Lockfile avanzato", french: "Lockfile avancé", spanish: "Lockfile avanzado"),
                systemImage: "doc.text.magnifyingglass"
            )
            .font(.callout.weight(.semibold))
        }
    }

    private var moreNodesText: String {
        let remainingCount = result.typedPlan.nodes.count - 18
        return localizedString(
            theme.language,
            english: "\(remainingCount) more nodes",
            chinese: "另有 \(remainingCount) 个节点",
            italian: "Altri \(remainingCount) nodi",
            french: "\(remainingCount) noeuds en plus",
            spanish: "\(remainingCount) nodos más"
        )
    }
}

private struct LockfileNodeRow: View {
    let node: CoreInstallPlanNode

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(node.action)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.caption.weight(.semibold))
                    .paninoTruncation(.title)
                Text([node.kind, node.targetPath].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
