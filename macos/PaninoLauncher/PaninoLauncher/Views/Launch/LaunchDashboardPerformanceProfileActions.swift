import Foundation

extension LaunchDashboard {
    func reviewPerformanceProfileAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openSettings
        }
        let request = CorePerformanceProfileResolveRequest(
            gameDir: instance.gameDirectory,
            instanceFingerprint: CoreInstanceFingerprint(
                minecraftVersion: instance.contentMinecraftVersion,
                javaRequirement: nil,
                loaderFamily: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                rendererCapability: instance.graphicsProfile.rawValue,
                modCount: versionStore.managedAssets.count,
                shaderLoader: nil,
                activeShaderPackHash: nil,
                resourcePackScale: nil,
                lockfileFingerprint: nil,
                worldTypeHint: nil
            ),
            knobs: CorePerformanceKnobs(
                heapMaxMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.memoryMb,
                heapInitialPolicy: instance.memoryPolicy.rawValue,
                gcPolicy: instance.jvmProfile.rawValue,
                renderDistance: nil,
                simulationDistance: nil,
                maxFps: nil,
                vsyncPolicy: instance.graphicsProfile.rawValue,
                particles: nil,
                clouds: nil,
                entityDistanceScaling: nil,
                performancePackSet: []
            ),
            evidence: performanceReviewEvidence(for: instance)
        )
        return {
            showPerformanceProfileReview = true
            performanceCoachStore.resolveBaseline(request: request)
        }
    }

    func applySelectedPerformanceProfile(_ profile: CorePerformanceProfile) {
        updateSelectedInstance { instance in
            if let heapMaxMb = profile.knobs.heapMaxMb {
                instance.memoryPolicy = .custom
                instance.customMemoryMb = heapMaxMb
                instance.memoryMb = heapMaxMb
            }

            if let gcPolicy = profile.knobs.gcPolicy?.lowercased() {
                if gcPolicy.contains("zgc") {
                    instance.jvmProfile = .experimentalZgc
                } else if gcPolicy != "auto" && gcPolicy != "default" && gcPolicy != "g1_or_default" {
                    instance.jvmProfile = .custom
                }
            }

            if profile.knobs.renderDistance != nil
                || profile.knobs.simulationDistance != nil
                || profile.knobs.maxFps != nil
                || profile.knobs.vsyncPolicy != nil
                || profile.knobs.particles != nil
                || profile.knobs.clouds != nil
                || profile.knobs.entityDistanceScaling != nil {
                instance.graphicsProfile = .performance
            }
        }
    }

    private func performanceReviewEvidence(for instance: GameInstance) -> [CorePerformanceEvidence] {
        let summaryEvidence = selectedPerformanceSummary?.evidence ?? []
        return summaryEvidence + [
            CorePerformanceEvidence(key: "source", value: "launch-ui", source: "swift"),
            CorePerformanceEvidence(key: "jvmProfile", value: instance.jvmProfile.rawValue, source: "instance"),
            CorePerformanceEvidence(key: "graphicsProfile", value: instance.graphicsProfile.rawValue, source: "instance")
        ]
    }
}
