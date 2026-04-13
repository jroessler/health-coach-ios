import Foundation
import SwiftData

@Model
final class CoachSummary {
    var generatedAt: Date
    var shortTermDays: Int
    var longTermDays: Int
    var markdownContent: String

    init(generatedAt: Date, shortTermDays: Int, longTermDays: Int, markdownContent: String) {
        self.generatedAt = generatedAt
        self.shortTermDays = shortTermDays
        self.longTermDays = longTermDays
        self.markdownContent = markdownContent
    }
}
