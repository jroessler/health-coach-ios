import Foundation
import SwiftData

@Model
final class ExerciseTemplate {
    @Attribute(.unique) var templateId: String
    var title: String
    var exerciseType: String?
    var muscle: String?
    var secondaryMuscle: String?
    var equipmentCategory: String?

    init(templateId: String, title: String) {
        self.templateId = templateId
        self.title = title
    }
}
