import SwiftUI

/// Compact numeric dates (e.g. 3/11) for chart x-axes — avoids clipped rotated labels.
enum NutritionChartDateAxisLabel {
    static func make(_ date: Date) -> Text {
        Text(date, format: .dateTime.month(.defaultDigits).day(.defaultDigits))
    }
}
