import Foundation
import SwiftUI

extension GameInstance {
    var resolvedIconName: String {
        iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "cube.fill" : iconName
    }

    var coverTintColor: Color {
        Color.paninoHex(coverColorHex, fallback: status.badgeStyle.color)
    }
}
