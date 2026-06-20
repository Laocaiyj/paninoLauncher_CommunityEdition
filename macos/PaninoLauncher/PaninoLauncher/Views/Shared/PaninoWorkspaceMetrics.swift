import SwiftUI

enum PaninoWorkspaceWidthClass: Equatable {
    case compact
    case regular
    case wide

    init(width: CGFloat) {
        if width >= 1500 {
            self = .wide
        } else if width >= 1050 {
            self = .regular
        } else {
            self = .compact
        }
    }

    var isCompact: Bool { self == .compact }
    var showsInspectorInline: Bool { self == .wide }
}

struct PaninoWorkspaceMetrics: Equatable {
    let availableWidth: CGFloat
    let widthClass: PaninoWorkspaceWidthClass
    let pagePadding: CGFloat
    let contentWidth: CGFloat

    init(availableWidth: CGFloat) {
        self.availableWidth = availableWidth
        self.widthClass = PaninoWorkspaceWidthClass(width: availableWidth)
        self.pagePadding = PaninoTokens.Layout.pagePadding(for: availableWidth)
        self.contentWidth = PaninoTokens.Layout.contentWidth(for: availableWidth)
    }
}
