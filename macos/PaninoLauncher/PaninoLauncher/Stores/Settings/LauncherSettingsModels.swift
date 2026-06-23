import Foundation

enum CloseWindowBehavior: String, CaseIterable, Identifiable {
    case quit
    case hide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quit:
            return "Quit"
        case .hide:
            return "Hide in Background"
        }
    }
}

enum DownloadSource: String, CaseIterable, Identifiable {
    case official
    case bmclapi
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .official:
            return "Official"
        case .bmclapi:
            return "BMCLAPI"
        case .custom:
            return "Custom"
        }
    }

    static var selectableCases: [DownloadSource] {
        [.official, .bmclapi]
    }
}

enum DownloadStrategy: String, CaseIterable, Identifiable {
    case auto
    case fast
    case conservative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .fast:
            return "Fast"
        case .conservative:
            return "Conservative"
        }
    }

    var detail: String {
        switch self {
        case .auto:
            return "Core adapts host gates and worker count from current throughput."
        case .fast:
            return "Raises worker budget for stable fast links and Range-capable large files."
        case .conservative:
            return "Caps worker pressure for weak networks, strict proxies, or low-resource hosts."
        }
    }
}

enum PerformanceApplyMode: String, CaseIterable, Identifiable {
    case automatic
    case ask
    case never

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .automatic:
            return localizedString(language, english: "Auto apply", chinese: "自动应用", italian: "Applica automaticamente", french: "Appliquer auto", spanish: "Aplicar auto")
        case .ask:
            return localizedString(language, english: "Ask first", chinese: "先询问", italian: "Chiedi prima", french: "Demander", spanish: "Preguntar")
        case .never:
            return localizedString(language, english: "Never apply", chinese: "永不自动应用", italian: "Mai applicare", french: "Jamais", spanish: "Nunca")
        }
    }
}

enum CacheScope: String, CaseIterable, Identifiable {
    case downloadStaging
    case metadataHttp
    case verificationIndex
    case urlCache

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloadStaging:
            return "Download staging"
        case .metadataHttp:
            return "Core metadata HTTP"
        case .verificationIndex:
            return "Verification index"
        case .urlCache:
            return "App URL cache"
        }
    }
}

struct CacheScopeSummary: Identifiable, Equatable {
    let scope: CacheScope
    let path: String
    let exists: Bool
    let bytes: Int64?

    var id: CacheScope { scope }

    var title: String { scope.title }

    var sizeText: String {
        guard let bytes else { return "-" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
