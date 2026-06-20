import Foundation

extension OnlineContentDiscoveryPage {
    func debounceMinecraftInstallPreflight() {
        minecraftInstallPreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallPreflight = nil
            minecraftInstallPreflightStatus = ""
            return
        }
        let targetGameDir: String? = nil
        let loader = selectedMinecraftLoader?.rawValue
        let shader = minecraftShaderLoaderForPreflight(loader: loader, shaderLoader: selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue)
        let name = minecraftInstallDisplayName(for: version)
        minecraftInstallPreflightStatus = localizedString(theme.language, english: "Checking install compatibility...", chinese: "正在检查安装兼容性...", italian: "Controllo compatibilità...", french: "Vérification compatibilité...", spanish: "Comprobando compatibilidad...")
        minecraftInstallPreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await viewModel.installPreflight(
                    CoreLoaderInstallPreflightRequest(
                        version: version.id,
                        gameDir: targetGameDir,
                        loader: loader,
                        loaderVersion: selectedMinecraftLoaderVersion,
                        shaderLoader: shader,
                        shaderVersion: automaticMinecraftInstallShaderVersion(),
                        instanceName: name
                    )
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = result
                    minecraftInstallPreflightStatus = ""
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = nil
                    minecraftInstallPreflightStatus = localizedString(
                        theme.language,
                        english: "Preflight failed: \(error.localizedDescription)",
                        chinese: "预检失败：\(error.localizedDescription)",
                        italian: "Preflight fallito: \(error.localizedDescription)",
                        french: "Précontrôle échoué : \(error.localizedDescription)",
                        spanish: "Preflight falló: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func debounceMinecraftInstallChoicePreflights() {
        minecraftInstallChoicePreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallChoicePreflights = [:]
            return
        }
        let targetGameDir: String? = nil
        let selectedLoader = selectedMinecraftLoader?.rawValue
        let selectedShader = selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue
        let name = minecraftInstallDisplayName(for: version)
        let loaderCandidates: [String?] = [nil] + LoaderKind.allCases.map { Optional($0.rawValue) }
        let shaderCandidates: [String?] = [nil] + ShaderLoaderChoice.allCases
            .filter { $0 != .none }
            .map { Optional($0.rawValue) }
        var requests: [(key: String, loader: String?, shader: String?)] = []
        for loaderCandidate in loaderCandidates {
            let shaderForCandidate = minecraftShaderLoaderForPreflight(loader: loaderCandidate, shaderLoader: selectedShader)
            requests.append((
                key: minecraftInstallChoiceKey(loader: loaderCandidate, shaderLoader: shaderForCandidate),
                loader: loaderCandidate,
                shader: shaderForCandidate
            ))
        }
        for shaderCandidate in shaderCandidates {
            requests.append((
                key: minecraftInstallChoiceKey(loader: selectedLoader, shaderLoader: shaderCandidate),
                loader: selectedLoader,
                shader: shaderCandidate
            ))
        }
        let uniqueRequests = requests.reduce(into: [(key: String, loader: String?, shader: String?)]()) { result, request in
            if !result.contains(where: { $0.key == request.key }) {
                result.append(request)
            }
        }
        minecraftInstallChoicePreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            var results: [String: CoreLoaderInstallPreflightResponse] = [:]
            for request in uniqueRequests {
                guard !Task.isCancelled else { return }
                do {
                    let result = try await viewModel.inspectInstallPreflight(
                        CoreLoaderInstallPreflightRequest(
                            version: version.id,
                            gameDir: targetGameDir,
                            loader: request.loader,
                            loaderVersion: request.loader == selectedLoader ? selectedMinecraftLoaderVersion : nil,
                            shaderLoader: request.shader,
                            shaderVersion: request.shader == selectedShader ? automaticMinecraftInstallShaderVersion() : nil,
                            instanceName: name
                        )
                    )
                    results[request.key] = result
                } catch {
                    continue
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                minecraftInstallChoicePreflights = results
            }
        }
    }
}
