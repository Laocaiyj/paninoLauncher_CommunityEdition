import SwiftUI

struct TaowaProfileTestPanel: View {
    let test: CoreTaowaFrpProfileTestResponse
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    test.ok
                        ? localizedString(theme.language, english: "Profile test passed", chinese: "配置测试通过", italian: "Test profilo riuscito", french: "Test du profil réussi", spanish: "Prueba de perfil superada")
                        : localizedString(theme.language, english: "Profile test needs attention", chinese: "配置测试需要处理", italian: "Test profilo da controllare", french: "Test du profil à vérifier", spanish: "Prueba de perfil requiere atención"),
                    systemImage: test.ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(style.color)
                Spacer()
                StatusBadge(title: test.ok ? "ok" : localizedString(theme.language, english: "check failed", chinese: "检查失败", italian: "controllo fallito", french: "échec", spanish: "falló"), style: style)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(test.checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.ok ? StatusBadge.Style.success.color : StatusBadge.Style.error.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(check.name)
                                .font(.caption.weight(.semibold))
                            Text(check.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background((check.ok ? Color.green : Color.red).opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(10)
        .background(style.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.color.opacity(0.18), lineWidth: 1)
        }
    }

    private var style: StatusBadge.Style {
        test.ok ? .success : .warning
    }
}
