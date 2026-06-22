import SwiftUI

struct PanelHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
    }
}
