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
