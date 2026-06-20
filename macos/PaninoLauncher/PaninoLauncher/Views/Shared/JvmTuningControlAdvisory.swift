import SwiftUI

extension JvmTuningControl {
    var advisoryText: String? {
        if let lastSnapshot, lastSnapshot.state == .failed {
            if lastSnapshot.heapOutOfMemory || lastSnapshot.nativeOutOfMemory || lastSnapshot.gcOverheadLimit {
                return localizedString(
                    theme.language,
                    english: "Last launch looked memory-related. Restore a known-good setup first, then adjust only if it still fails.",
                    chinese: "上次启动像是内存相关失败。先恢复可用设置，再根据结果微调。",
                    italian: "L'ultimo avvio sembra legato alla memoria. Ripristina una configurazione funzionante prima di ritoccare.",
                    french: "Le dernier lancement semble lié à la mémoire. Restaurez un réglage fiable avant d'ajuster.",
                    spanish: "El último inicio parece de memoria. Restaura una configuración válida antes de ajustar."
                )
            }
            return localizedString(
                theme.language,
                english: "Last launch failed. Panino will not change settings silently.",
                chinese: "上次启动失败。Panino 不会在你不知情时改配置。",
                italian: "Ultimo avvio non riuscito. Panino non cambia impostazioni senza dirtelo.",
                french: "Dernier lancement échoué. Panino ne change rien sans vous prévenir.",
                spanish: "El último inicio falló. Panino no cambia ajustes sin avisar."
            )
        }
        if hasCustomJvmConflict {
            return localizedString(
                theme.language,
                english: "Custom advanced launch flags conflict with automatic tuning. Core will keep one final recommendation.",
                chinese: "自定义高级启动参数会和自动调校冲突。Core 最终只保留一组推荐。",
                italian: "Flag avanzati personalizzati confliggono con l'autotuning. Core conserva una raccomandazione.",
                french: "Les options avancées personnalisées entrent en conflit. Core garde une recommandation finale.",
                spanish: "Los flags avanzados chocan con el ajuste automático. Core deja una recomendación final."
            )
        }
        if memoryPolicy == .custom, (customMemoryMb ?? currentMemoryMb) >= 12 * 1024 {
            return localizedString(
                theme.language,
                english: "Very large game memory can starve macOS unified memory and make the game slower.",
                chinese: "游戏内存太大可能挤压 macOS 统一内存，反而让游戏更卡。",
                italian: "Memoria gioco troppo grande può comprimere la memoria unificata di macOS e rallentare.",
                french: "Une mémoire jeu trop grande peut étouffer la mémoire unifiée macOS et ralentir.",
                spanish: "Memoria de juego muy grande puede presionar la memoria unificada de macOS y ralentizar."
            )
        }
        return nil
    }

    var advisoryIcon: String {
        failedWithRollback ? "exclamationmark.triangle" : "info.circle"
    }

    var advisoryColor: Color {
        failedWithRollback || hasCustomJvmConflict ? .orange : .secondary
    }

    var hasCustomJvmConflict: Bool {
        splitJvmArguments(customJvmArguments).contains { argument in
            argument.hasPrefix("-Xmx")
                || argument.hasPrefix("-Xms")
                || argument.contains("UseZGC")
                || argument.contains("UseG1GC")
                || argument.contains("UseShenandoahGC")
                || argument.contains("UseParallelGC")
                || argument.contains("UseSerialGC")
        }
    }
}
