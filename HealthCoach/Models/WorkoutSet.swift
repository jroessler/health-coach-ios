import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var workout: Workout?
    var exerciseTitle: String
    var supersetId: String?
    var exerciseNotes: String?
    var setIndex: Int?
    var setType: String?
    var weightKg: Double?
    var reps: Int?
    var distanceKm: Double?
    var durationSeconds: Double?
    var rpe: Double?
    var date: String

    init(exerciseTitle: String, date: String) {
        self.exerciseTitle = exerciseTitle
        self.date = date
    }
}
