import SwiftUI

enum OnlineProjectDetailPresentation {
    case full
    case inspector
}

struct OnlineProjectDetailPanel: View {
    var presentation: OnlineProjectDetailPresentation = .full
    let project: OnlineProject
    let releases: [OnlineRelease]
    @Binding var selectedReleaseID: String?
    let currentMinecraftVersion: String?
    let targetResolution: CoreContentResolveTargetsResponse?
    @Binding var selectedTargetID: String?
    let targetFailure: String?
    let projectFailure: String?
    let isLoading: Bool
    let retryLoad: () -> Void
    let install: (CoreContentTargetCandidate?) -> Void
    let openTasks: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    private var compatibleReleases: [OnlineRelease] {
        guard let currentMinecraftVersion else { return [] }
        return releases.filter { $0.gameVersions.contains(currentMinecraftVersion) }
    }

    private var selectedRelease: OnlineRelease? {
        if let selectedReleaseID,
           let release = compatibleReleases.first(where: { $0.id == selectedReleaseID }) {
            return release
        }
        return compatibleReleases.first
    }

    var body: some View {
        switch presentation {
        case .full:
            fullDetail
        case .inspector:
            inspectorDetail
        }
    }

    private var fullDetail: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 20) {
                ProjectImmersiveHeader(project: project, presentation: .full)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        contentColumn
                            .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)
                        actionColumn
                            .frame(width: 340, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        contentColumn
                        actionColumn
                    }
                }
            }
        }
        .frame(maxWidth: 1_260, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var inspectorDetail: some View {
        GlassPanel(showsShadow: false, surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 14) {
                ProjectImmersiveHeader(project: project, presentation: .inspector)

                actionColumn

                releasePickerSection

                ProjectDescriptionSection(text: project.description ?? project.summary, collapsedLineLimit: 6)

                Divider()

                ProjectMetadataSection(project: project, presentation: .inspector)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProjectDescriptionSection(text: project.description ?? project.summary, collapsedLineLimit: 7)
            ProjectMetadataSection(project: project, presentation: .full)
            releasePickerSection
        }
    }

    @ViewBuilder
    private var releasePickerSection: some View {
        if currentMinecraftVersion != nil || projectFailure != nil || isLoading {
            Divider()
            ReleasePickerSection(
                releases: releases,
                selectedReleaseID: $selectedReleaseID,
                currentMinecraftVersion: currentMinecraftVersion,
                projectFailure: projectFailure,
                isLoading: isLoading,
                retryLoad: retryLoad
            )
        }
    }

    @ViewBuilder
    private var actionColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            actionSection
            if let selectedRelease, project.projectType.managedAssetKind != nil {
                Divider()
                ReleaseFileDetailsSection(release: selectedRelease)
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if let selectedRelease, project.projectType.managedAssetKind != nil {
            InstallTargetSection(
                release: selectedRelease,
                currentMinecraftVersion: currentMinecraftVersion,
                targetResolution: targetResolution,
                selectedTargetID: $selectedTargetID,
                targetFailure: targetFailure,
                install: install,
                openTasks: openTasks
            )
        } else if project.projectType == .modpack {
            OnlineUnsupportedInstallFlowView(
                title: localizedString(theme.language, english: "Modpack import flow", chinese: "整合包导入流程", italian: "Importazione modpack", french: "Import modpack", spanish: "Importar modpack"),
                message: localizedString(theme.language, english: "Modpacks create or import a dedicated local instance. That flow is separate from installing single content files into an existing instance.", chinese: "整合包会创建或导入专用本地实例，不会直接写入已有普通实例。", italian: "I modpack creano o importano un'istanza dedicata.", french: "Les modpacks créent ou importent une instance dédiée.", spanish: "Los modpacks crean una instancia dedicada.")
            )
        } else {
            OnlineUnsupportedInstallFlowView(
                title: localizedString(theme.language, english: "Choose a Minecraft version", chinese: "选择 Minecraft 版本", italian: "Scegli una versione Minecraft", french: "Choisir une version Minecraft", spanish: "Elige una versión de Minecraft"),
                message: localizedString(theme.language, english: "Select a Minecraft release filter above to load installable files and compatible local targets.", chinese: "请先在上方选择 Minecraft 正式版过滤器，以加载可安装文件和兼容本地目标。", italian: "Seleziona un filtro Minecraft per caricare file e destinazioni.", french: "Sélectionnez une version Minecraft pour charger les fichiers et cibles.", spanish: "Selecciona una versión de Minecraft para cargar archivos y destinos.")
            )
        }
    }
}
