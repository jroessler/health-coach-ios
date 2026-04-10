import Foundation
import SwiftData

@Model
final class HealthRecord {
    var category: String
    var metric: String
    var value: Double
    var unit: String
    var source: String
    var startDate: String
    var endDate: String
    var date: String

    init(
        category: String,
        metric: String,
        value: Double,
        unit: String,
        source: String,
        startDate: String,
        endDate: String,
        date: String
    ) {
        self.category = category
        self.metric = metric
        self.value = value
        self.unit = unit
        self.source = source
        self.startDate = startDate
        self.endDate = endDate
        self.date = date
    }
}
