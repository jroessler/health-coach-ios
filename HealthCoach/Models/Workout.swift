import Foundation
import SwiftData

@Model
final class Workout {
    var title: String
    var startTime: String
    var endTime: String
    var durationMin: Double
    var workoutDescription: String
    var date: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workout)
    var sets: [WorkoutSet] = []

    init(
        title: String,
        startTime: String,
        endTime: String,
        durationMin: Double,
        workoutDescription: String,
        date: String
    ) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.durationMin = durationMin
        self.workoutDescription = workoutDescription
        self.date = date
    }
}
