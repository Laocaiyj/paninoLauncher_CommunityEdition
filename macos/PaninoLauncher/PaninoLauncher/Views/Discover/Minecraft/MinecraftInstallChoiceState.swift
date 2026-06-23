import Foundation

extension MinecraftVersionInstallDetailPage {
    var compatibleLoaders: [LoaderKind] {
        version.kind == .oldAlpha || version.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    func selectLoader(_ candidate: LoaderKind?) {
        loaderVersion = nil
        shaderLoaderVersion = nil
        loader = candidate
        if !minecraftShaderLoaderCompatible(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue) {
            shaderLoader = .none
        }
    }

    func loaderChoiceState(_ candidate: LoaderKind?) -> InstallChoicePreflightState {
        let shader = minecraftShaderLoaderForPreflight(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue)
        let result = choicePreflights[minecraftInstallChoiceKey(loader: candidate?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: candidate == loader ? preflight : nil)
    }

    func shaderChoiceState(_ choice: ShaderLoaderChoice) -> InstallChoicePreflightState {
        if shaderChoiceDisabled(choice) {
            return .blocked
        }
        let shader = choice == .none ? nil : choice.rawValue
        let result = choicePreflights[minecraftInstallChoiceKey(loader: loader?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: choice == shaderLoader ? preflight : nil)
    }

    func shaderChoiceDisabled(_ choice: ShaderLoaderChoice) -> Bool {
        choice != .none && !minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: choice.rawValue)
    }

    var selectedShaderLoaderRawValue: String? {
        shaderLoader == .none ? nil : shaderLoader.rawValue
    }

    var selectedShaderLoaderIsCompatible: Bool {
        minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: selectedShaderLoaderRawValue)
    }

    var effectiveShaderLoader: ShaderLoaderChoice? {
        selectedShaderLoaderIsCompatible && shaderLoader != .none ? shaderLoader : nil
    }

    private func installChoiceState(from result: CoreLoaderInstallPreflightResponse?, fallback: CoreLoaderInstallPreflightResponse?) -> InstallChoicePreflightState {
        let resolved = result ?? fallback
        if let resolved, hasChoiceCompatibilityBlocker(resolved) {
            return .blocked
        }
        if resolved?.isBlocked == true || resolved?.status == "warning" || resolved?.warnings.isEmpty == false {
            return .warning
        }
        return .normal
    }

    private func hasChoiceCompatibilityBlocker(_ preflight: CoreLoaderInstallPreflightResponse) -> Bool {
        preflight.blockedReasons.contains { reason in
            let normalized = reason.lowercased()
            return normalized.hasPrefix("loader_version_not_found")
                || normalized.hasPrefix("loader_profile_not_found")
                || normalized.hasPrefix("loader_profile_url_not_found")
                || normalized.hasPrefix("loader_installer_not_found")
                || normalized.hasPrefix("forge_installer_url_not_found")
                || normalized.hasPrefix("neoforge_installer_url_not_found")
                || normalized.hasPrefix("shader_loader_incompatible")
                || normalized.hasPrefix("shader_release_not_found")
                || normalized.hasPrefix("shader_dependency_unresolved")
        }
    }
}
