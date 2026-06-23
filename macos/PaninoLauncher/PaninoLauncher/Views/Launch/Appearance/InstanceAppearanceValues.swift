import Foundation

struct InstanceAppearanceValues: Equatable {
    var iconName: String
    var coverPath: String
    var coverColorHex: String
    var coverFocusX: Double
    var coverFocusY: Double
    var coverBlur: Double
    var coverDim: Double
    var iconBackdropStyle: InstanceIconBackdropStyle

    init(instance: GameInstance) {
        iconName = instance.iconName
        coverPath = instance.coverPath
        coverColorHex = instance.coverColorHex
        coverFocusX = instance.coverFocusX
        coverFocusY = instance.coverFocusY
        coverBlur = instance.coverBlur
        coverDim = instance.coverDim
        iconBackdropStyle = instance.iconBackdropStyle
    }

    init(
        iconName: String,
        coverPath: String,
        coverColorHex: String,
        coverFocusX: Double,
        coverFocusY: Double,
        coverBlur: Double,
        coverDim: Double,
        iconBackdropStyle: InstanceIconBackdropStyle
    ) {
        self.iconName = iconName
        self.coverPath = coverPath
        self.coverColorHex = coverColorHex
        self.coverFocusX = coverFocusX
        self.coverFocusY = coverFocusY
        self.coverBlur = coverBlur
        self.coverDim = coverDim
        self.iconBackdropStyle = iconBackdropStyle
    }

    var normalized: InstanceAppearanceValues {
        let trimmedIconName = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCoverColor = coverColorHex.normalizedHex
        return InstanceAppearanceValues(
            iconName: trimmedIconName.isEmpty ? "cube.fill" : trimmedIconName,
            coverPath: coverPath.trimmingCharacters(in: .whitespacesAndNewlines),
            coverColorHex: normalizedCoverColor.isEmpty ? GameInstance.defaultCoverColorHex : normalizedCoverColor,
            coverFocusX: GameInstance.clampedUnit(coverFocusX),
            coverFocusY: GameInstance.clampedUnit(coverFocusY),
            coverBlur: GameInstance.clampedUnit(coverBlur),
            coverDim: GameInstance.clampedUnit(coverDim),
            iconBackdropStyle: iconBackdropStyle
        )
    }
}

extension GameInstance {
    mutating func applyAppearance(_ values: InstanceAppearanceValues) {
        iconName = values.iconName
        coverPath = values.coverPath
        coverColorHex = values.coverColorHex
        coverFocusX = values.coverFocusX
        coverFocusY = values.coverFocusY
        coverBlur = values.coverBlur
        coverDim = values.coverDim
        iconBackdropStyle = values.iconBackdropStyle
    }
}
