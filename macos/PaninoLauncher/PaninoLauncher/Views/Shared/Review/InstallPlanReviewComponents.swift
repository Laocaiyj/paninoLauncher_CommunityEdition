import SwiftUI

struct InstallPlanReviewHeader: View {
    let title: String
    let subtitle: String
    let isBlocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isBlocked ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(isBlocked ? Color.orange : Color.green)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .paninoTruncation(.title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .paninoTruncation(.summary(lines: 2))
            }

            Spacer(minLength: 0)
        }
    }
}

struct InstallPlanReviewTextSection: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.30),
            in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
        )
    }
}

struct InstallPlanAdvancedDisclosure: View {
    let plan: CoreTypedInstallPlan
    let language: AppLanguage

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                InstallPlanIdentityBlock(plan: plan)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.nodes.prefix(18), id: \.id) { node in
                        InstallPlanNodeRow(node: node)
                    }
                    if plan.nodes.count > 18 {
                        Text(moreNodesText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label(
                localizedString(language, english: "Advanced plan", chinese: "高级计划", italian: "Piano avanzato", french: "Plan avancé", spanish: "Plan avanzado"),
                systemImage: "point.3.connected.trianglepath.dotted"
            )
            .font(.callout.weight(.semibold))
        }
    }

    private var moreNodesText: String {
        let count = plan.nodes.count - 18
        return localizedString(language, english: "\(count) more nodes", chinese: "另有 \(count) 个节点", italian: "Altri \(count) nodi", french: "\(count) noeuds en plus", spanish: "\(count) nodos más")
    }
}

private struct InstallPlanIdentityBlock: View {
    let plan: CoreTypedInstallPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("planId: \(plan.planId)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("fingerprint: \(plan.fingerprint)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let targetGameDir = plan.targetGameDir {
                Text("target: \(targetGameDir)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("edges: \(plan.edges.count) · rollback: \(plan.rollbackPolicy)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

private struct InstallPlanNodeRow: View {
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
                HStack(spacing: 8) {
                    Text(node.kind)
                    if let targetPath = node.targetPath {
                        Text(targetPath)
                    }
                    if let sha1 = node.sha1 {
                        Text(sha1)
                    }
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}
