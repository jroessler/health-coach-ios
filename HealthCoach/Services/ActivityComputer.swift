import Foundation
import SwiftData

// Mirrors health/app/services/activity.py — all formulas ported 1:1.
// Runs off the main thread via @ModelActor; returns pure Sendable structs.

@ModelActor
actor ActivityComputer {

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    // MARK: - Public entry point

    func compute(
        dateStart: Date,
        dateEnd: Date,
        muscleTargets: [String: Double]
    ) -> ActivitySnapshot? {
        do {
            let workouts: [ActivityWorkoutInput]
            let sets: [ActivitySetInput]
            let templateMap: [String: String]
            var totalWorkoutCount = 0
            do {
                let ctx = ModelContext(modelContainer)
                let allWorkouts = try ctx.fetch(FetchDescriptor<Workout>())
                totalWorkoutCount = allWorkouts.count
                workouts = allWorkouts.compactMap { w -> ActivityWorkoutInput? in
                    guard let d = Self.dateFmt.date(from: w.date) else { return nil }
                    let st = Self.parseDateTime(w.startTime) ?? d
                    return ActivityWorkoutInput(date: d, startTime: st, durationMin: w.durationMin)
                }

                let allSets = try ctx.fetch(FetchDescriptor<WorkoutSet>())
                sets = allSets.compactMap { s -> ActivitySetInput? in
                    guard let d = Self.dateFmt.date(from: s.date) else { return nil }
                    return ActivitySetInput(
                        date: d,
                        exerciseTitle: s.exerciseTitle,
                        setType: s.setType ?? "",
                        weightKg: s.weightKg ?? 0,
                        reps: Double(s.reps ?? 0)
                    )
                }

                let allTemplates = try ctx.fetch(FetchDescriptor<ExerciseTemplate>())
                templateMap = Dictionary(
                    allTemplates.compactMap { t -> (String, String)? in
                        guard let m = t.muscle else { return nil }
                        return (t.title, m)
                    },
                    uniquingKeysWith: { first, _ in first }
                )
            }

            let activityRows = try HealthRecordStore.shared.loadActivityDaily()

            let workoutKPIs = ActivityKPIMath.computeWorkoutKPIs(
                workouts: workouts,
                totalWorkoutCount: totalWorkoutCount,
                dateStart: dateStart,
                dateEnd: dateEnd
            )
            let muscleRadar = ActivityKPIMath.computeMuscleRadar(
                sets,
                templateMap: templateMap,
                dateStart: dateStart,
                dateEnd: dateEnd,
                muscleTargets: muscleTargets
            )
            let volumeProgression = ActivityKPIMath.computeVolumeProgression(
                sets,
                templateMap: templateMap,
                dateEnd: dateEnd
            )
            let activityKPIs = ActivityKPIMath.computeActivityKPIs(
                activityRows,
                dateStart: dateStart,
                dateEnd: dateEnd
            )
            let energyTDEE = ActivityKPIMath.computeEnergyTDEE(
                activityRows,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            return ActivitySnapshot(
                workoutKPIs: workoutKPIs,
                muscleRadar: muscleRadar,
                volumeProgression: volumeProgression,
                activityKPIs: activityKPIs,
                energyTDEE: energyTDEE
            )
        } catch {
            return nil
        }
    }

    private static let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFmtNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static func parseDateTime(_ s: String) -> Date? {
        isoFmt.date(from: s) ?? isoFmtNoFrac.date(from: s)
    }
}
