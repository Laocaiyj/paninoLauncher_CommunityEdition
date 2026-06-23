import SwiftUI

let detailMetricColumns: [GridItem] = [
    GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)
]

func optionalFormattedBytes(_ bytes: Int64?) -> String {
    bytes.map(formattedBytes) ?? "-"
}
