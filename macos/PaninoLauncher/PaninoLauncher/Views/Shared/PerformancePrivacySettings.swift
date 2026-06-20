import SwiftUI

struct PerformancePrivacySettings: View {
    @Binding var keepLocalSessions: Bool
    @Binding var allowExperiments: Bool
    @Binding var shareAnonymousPriors: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(localizedString(language, english: "Keep local performance sessions", chinese: "保留本机性能会话", italian: "Conserva sessioni locali", french: "Garder les sessions locales", spanish: "Guardar sesiones locales"), isOn: $keepLocalSessions)
                .toggleStyle(.switch)
            Toggle(localizedString(language, english: "Allow one-candidate experiments", chinese: "允许单候选实验", italian: "Consenti esperimenti", french: "Autoriser les essais", spanish: "Permitir experimentos"), isOn: $allowExperiments)
                .toggleStyle(.switch)
            Toggle(localizedString(language, english: "Share anonymous profile priors", chinese: "分享匿名 profile priors", italian: "Condividi prior anonimi", french: "Partager des priors anonymes", spanish: "Compartir priors anónimos"), isOn: $shareAnonymousPriors)
                .toggleStyle(.switch)
            Label(
                localizedString(
                    language,
                    english: "Performance data stays in the instance folder by default. Anonymous priors are opt-in and aggregate-only.",
                    chinese: "性能数据默认只保存在实例目录。匿名 priors 必须显式开启，且只使用聚合指标。",
                    italian: "I dati restano nella cartella istanza. I prior anonimi sono facoltativi e aggregati.",
                    french: "Les données restent dans le dossier d'instance. Les priors anonymes sont optionnels et agrégés.",
                    spanish: "Los datos quedan en la instancia. Los priors anónimos son opcionales y agregados."
                ),
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
