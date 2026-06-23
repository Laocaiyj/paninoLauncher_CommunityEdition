import SwiftUI

enum PaninoTokens {
    enum Window {
        static let minimumWidth: CGFloat = 1280
        static let minimumHeight: CGFloat = 760
        static let minimumMainWidth: CGFloat = 680
    }

    enum Layout {
        static let contentMaxWidth: CGFloat = 1120
        static let contentWideMaxWidth: CGFloat = 1680
        static let contentReadableMaxWidth: CGFloat = 1040
        static let inspectorWidth: CGFloat = 360
        static let sectionSpacing: CGFloat = 16
        static let sectionInnerSpacing: CGFloat = 10
        static let pageTopSpacing: CGFloat = 24
        static let rowHeightCompact: CGFloat = 64
        static let rowHeightComfortable: CGFloat = 92
        static let shelfCardWidth: CGFloat = 188
        static let heroMinHeight: CGFloat = 420
        static let pageHorizontalPadding: CGFloat = 32
        static let compactPageHorizontalPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 22
        static let secondarySidebarWidth: CGFloat = 212
        static let compactResultRowHeight: CGFloat = 68
        static let instanceCardHeight: CGFloat = 84
        static let controlMinSize: CGFloat = 36
        static let primaryButtonMinHeight: CGFloat = 44
        static let topNavigationHeight: CGFloat = 54

        static func contentWidth(for availableWidth: CGFloat) -> CGFloat {
            if availableWidth >= 2200 {
                return min(availableWidth - 220, 1880)
            }
            if availableWidth >= 1800 {
                return min(availableWidth - 160, contentWideMaxWidth)
            }
            if availableWidth >= 1440 {
                return min(availableWidth - 96, 1480)
            }
            if availableWidth >= 1280 {
                return 1120
            }
            return max(availableWidth - compactPageHorizontalPadding * 2, 680)
        }

        static func pagePadding(for availableWidth: CGFloat) -> CGFloat {
            availableWidth < 960 ? compactPageHorizontalPadding : pageHorizontalPadding
        }
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 8
        static let panel: CGFloat = 12
    }

    enum Shadow {
        static let panelOpacity: Double = 0.08
    }
}

enum PaninoLimits {
    static let memoryMb = 1024...16384
}

enum PaninoMotion {
    static let fast = Animation.interpolatingSpring(stiffness: 360, damping: 34)
    static let standard = Animation.interpolatingSpring(stiffness: 260, damping: 30)
    static let page = Animation.interpolatingSpring(stiffness: 220, damping: 32)

    static func noneWhenReduced(_ animation: Animation = standard, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
