import Foundation

struct OnlineCategoryOption: Identifiable, Hashable, Sendable {
    let id: String
    let projectTypes: Set<OnlineProjectType>
    let sources: Set<ContentSourceID>
    let priority: Int
    let englishTitle: String
    let chineseTitle: String
    let italianTitle: String
    let frenchTitle: String
    let spanishTitle: String

    func title(language: AppLanguage) -> String {
        localizedString(
            language,
            english: englishTitle,
            chinese: chineseTitle,
            italian: italianTitle,
            french: frenchTitle,
            spanish: spanishTitle
        )
    }
}

enum OnlineCategoryCatalog {
    static func options(for projectType: OnlineProjectType, source: ContentSourceID) -> [OnlineCategoryOption] {
        all
            .filter { $0.projectTypes.contains(projectType) && $0.sources.contains(source) && supports($0, projectType: projectType, source: source) }
            .sorted {
                if $0.priority == $1.priority {
                    return $0.englishTitle.localizedCaseInsensitiveCompare($1.englishTitle) == .orderedAscending
                }
                return $0.priority < $1.priority
            }
    }

    static func option(id: String, projectType: OnlineProjectType, source: ContentSourceID) -> OnlineCategoryOption? {
        options(for: projectType, source: source).first { $0.id == id }
    }

    private static func supports(_ option: OnlineCategoryOption, projectType: OnlineProjectType, source: ContentSourceID) -> Bool {
        if source == .curseForge && projectType == .shaderPack {
            return false
        }
        return true
    }
}

extension OnlineCategoryCatalog {
    static func option(
        _ id: String,
        types: Set<OnlineProjectType>,
        sources: Set<ContentSourceID>,
        priority: Int,
        english: String,
        chinese: String,
        italian: String,
        french: String,
        spanish: String
    ) -> OnlineCategoryOption {
        OnlineCategoryOption(
            id: id,
            projectTypes: types,
            sources: sources,
            priority: priority,
            englishTitle: english,
            chineseTitle: chinese,
            italianTitle: italian,
            frenchTitle: french,
            spanishTitle: spanish
        )
    }
}
