import Foundation
import SwiftUI

/// Shared x-axis stride for date-based nutrition charts (~4–6 labels; avoids overlap on narrow layouts).
enum NutritionChartAxisMetrics {
    /// Fixed width for numeric y-axis tick labels so dual stacked charts align horizontally.
    static let yAxisLabelWidth: CGFloat = 40
    /// Fixed height reserved for date labels on the x-axis (both overlay charts must match).
    static let xAxisLabelHeight: CGFloat = 14

    /// Stride in days between x-axis marks from point count (fallback when date bounds unavailable).
    static func dateStrideDays(pointCount: Int) -> Int {
        let n = max(1, pointCount)
        return max(2, min(14, n / 5))
    }

    /// Stride from calendar span of the selected range (preferred for date-domain charts).
    static func dateStrideDays(from start: Date, through end: Date, calendar: Calendar = .current) -> Int {
        let d0 = calendar.startOfDay(for: start)
        let d1 = calendar.startOfDay(for: end)
        let daySpan = max(1, (calendar.dateComponents([.day], from: d0, to: d1).day ?? 0) + 1)
        return max(2, min(14, daySpan / 5))
    }
}
