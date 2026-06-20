import SwiftUI

enum PaninoSurfaceLevel {
    case background
    case panel
    case elevatedPanel
    case floatingChrome
    case popover

    var veilMultiplier: Double {
        switch self {
        case .background: return 0.52
        case .panel: return 1.00
        case .elevatedPanel: return 0.82
        case .floatingChrome: return 0.64
        case .popover: return 0.72
        }
    }

    var fillOpacityMultiplier: Double {
        switch self {
        case .background: return 0.58
        case .panel: return 1.00
        case .elevatedPanel: return 0.88
        case .floatingChrome: return 0.74
        case .popover: return 0.92
        }
    }

    var accentMultiplier: Double {
        switch self {
        case .background: return 0.34
        case .panel: return 0.55
        case .elevatedPanel: return 0.70
        case .floatingChrome: return 0.86
        case .popover: return 0.76
        }
    }

    var tintOpacity: Double {
        switch self {
        case .background: return 0.025
        case .panel: return 0.070
        case .elevatedPanel: return 0.095
        case .floatingChrome: return 0.120
        case .popover: return 0.105
        }
    }

    var strokeMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.12
        case .floatingChrome: return 1.24
        case .popover: return 1.18
        }
    }

    var shadowMultiplier: Double {
        switch self {
        case .background: return 0.20
        case .panel: return 1.00
        case .elevatedPanel: return 1.18
        case .floatingChrome: return 1.42
        case .popover: return 1.30
        }
    }

    var shadowRadiusMultiplier: CGFloat {
        switch self {
        case .background: return 0.40
        case .panel: return 1.00
        case .elevatedPanel: return 1.12
        case .floatingChrome: return 1.28
        case .popover: return 1.22
        }
    }

    var shadowYOffsetMultiplier: CGFloat {
        switch self {
        case .background: return 0.35
        case .panel: return 1.00
        case .elevatedPanel: return 1.14
        case .floatingChrome: return 1.30
        case .popover: return 1.22
        }
    }

    var highlightMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.22
        case .floatingChrome: return 1.45
        case .popover: return 1.32
        }
    }

    var shadeMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.16
        case .floatingChrome: return 1.34
        case .popover: return 1.24
        }
    }
}
