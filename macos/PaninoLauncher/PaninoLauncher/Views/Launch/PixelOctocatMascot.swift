import SwiftUI

struct PixelOctocatMascot: View {
    let state: PixelOctocatState

    var body: some View {
        GeometryReader { proxy in
            let pixel = min(proxy.size.width / 24, proxy.size.height / 16)
            ZStack(alignment: .topLeading) {
                ForEach(Self.blocks(eyeShift: state.eyeShift, blink: state.blink), id: \.id) { block in
                    Rectangle()
                        .fill(block.tone.color)
                        .frame(width: pixel * CGFloat(block.width), height: pixel * CGFloat(block.height))
                        .offset(x: pixel * CGFloat(block.x), y: pixel * CGFloat(block.y))
                }
            }
            .offset(x: pixel * 3, y: pixel * 1)
        }
        .allowsHitTesting(false)
    }

    private static func blocks(eyeShift: Int, blink: Bool) -> [PixelOctocatBlock] {
        var blocks: [PixelOctocatBlock] = [
            PixelOctocatBlock(x: 8, y: 1, width: 2, height: 2, tone: .shell),
            PixelOctocatBlock(x: 14, y: 1, width: 2, height: 2, tone: .shell),
            PixelOctocatBlock(x: 7, y: 2, width: 4, height: 2, tone: .shell),
            PixelOctocatBlock(x: 13, y: 2, width: 4, height: 2, tone: .shell),
            PixelOctocatBlock(x: 6, y: 4, width: 12, height: 2, tone: .shell),
            PixelOctocatBlock(x: 5, y: 6, width: 14, height: 4, tone: .shell),
            PixelOctocatBlock(x: 6, y: 10, width: 12, height: 1, tone: .shell),
            PixelOctocatBlock(x: 8, y: 11, width: 8, height: 3, tone: .shell),
            PixelOctocatBlock(x: 7, y: 5, width: 10, height: 1, tone: .face),
            PixelOctocatBlock(x: 6, y: 6, width: 12, height: 4, tone: .face),
            PixelOctocatBlock(x: 7, y: 10, width: 10, height: 1, tone: .face),
            PixelOctocatBlock(x: 5, y: 5, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 17, y: 5, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 4, y: 8, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 18, y: 8, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 3, y: 9, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 19, y: 9, width: 2, height: 1, tone: .shell),
            PixelOctocatBlock(x: 8, y: 14, width: 1, height: 1, tone: .shell),
            PixelOctocatBlock(x: 10, y: 14, width: 1, height: 1, tone: .shell),
            PixelOctocatBlock(x: 13, y: 14, width: 1, height: 1, tone: .shell),
            PixelOctocatBlock(x: 15, y: 14, width: 1, height: 1, tone: .shell),
            PixelOctocatBlock(x: 11, y: 8, width: 3, height: 1, tone: .feature)
        ]
        if blink {
            blocks.append(PixelOctocatBlock(x: 8 + eyeShift, y: 7, width: 2, height: 1, tone: .feature))
            blocks.append(PixelOctocatBlock(x: 15 + eyeShift, y: 7, width: 2, height: 1, tone: .feature))
        } else {
            blocks.append(PixelOctocatBlock(x: 8 + eyeShift, y: 6, width: 1, height: 2, tone: .feature))
            blocks.append(PixelOctocatBlock(x: 15 + eyeShift, y: 6, width: 1, height: 2, tone: .feature))
        }
        return blocks
    }
}

struct PixelOctocatState {
    let seconds: TimeInterval

    var driftX: CGFloat {
        CGFloat(sin(seconds * 1.10) * 0.8)
    }

    var floatY: CGFloat {
        CGFloat(sin(seconds * 1.75) * 1.2)
    }

    var blink: Bool {
        let cycle = seconds.truncatingRemainder(dividingBy: 5.8)
        return (1.20..<1.36).contains(cycle) || (4.70..<4.86).contains(cycle)
    }

    var eyeShift: Int {
        let cycle = seconds.truncatingRemainder(dividingBy: 7.4)
        switch cycle {
        case 2.0..<3.35:
            return -1
        case 4.05..<5.40:
            return 1
        default:
            return 0
        }
    }
}

private struct PixelOctocatBlock {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let tone: PixelOctocatTone

    var id: String {
        "\(x)-\(y)-\(width)-\(height)-\(tone.rawValue)"
    }
}

private enum PixelOctocatTone: String {
    case shell
    case face
    case feature

    var color: Color {
        switch self {
        case .shell:
            return Color(red: 0.27, green: 0.31, blue: 0.35)
        case .face:
            return Color(red: 0.90, green: 0.93, blue: 0.94)
        case .feature:
            return Color(red: 0.27, green: 0.31, blue: 0.35)
        }
    }
}
