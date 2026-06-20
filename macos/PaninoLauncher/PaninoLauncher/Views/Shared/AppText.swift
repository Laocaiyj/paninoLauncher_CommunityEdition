enum AppText {
    case launch
    case instances
    case versions
    case account
    case tasks
    case logs
    case appearance
    case settings
    case launchSubtitle
    case instancesSubtitle
    case versionsSubtitle
    case accountSubtitle
    case tasksSubtitle
    case logsSubtitle
    case appearanceSubtitle
    case settingsSubtitle
    case startCore
    case stopCore
    case language
    case mode
    case accent
    case preset
    case apply
    case glass
    case background
    case choose
    case softTexture
    case enabled
    case density
    case versionSelector
    case channel
    case loaderPlan
    case loader
    case loaderPlanDescription
    case contentManager
    case refresh
    case openFolder
    case type
    case noItems
    case deleteSelectedFile
    case deleteFile
    case cancel
    case released
    case java
    case download
    case verify
    case enable
    case disable
    case delete
    case status
    case details
    case instanceDetails
    case readyForTasks
    case coreLogs
    case export
    case clear
    case microsoftAccount
    case signedIn
    case restoring
    case waiting
    case error
    case signedOut
    case ready
    case attention
    case failed
    case downloading
    case running
    case idle
    case openMicrosoft

    func localized(_ language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            return chineseSimplified
        case .english:
            return english
        case .italian:
            return italian
        case .french:
            return french
        case .spanish:
            return spanish
        }
    }

    func localized(_ language: AppLanguage, _ value: String) -> String {
        localized(language).replacingOccurrences(of: "%@", with: value)
    }
}
