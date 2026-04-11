import Foundation
import SwiftData

// Mirrors health/app/services/activity.py — all formulas ported 1:1.
// Runs off the main thread via @ModelActor; returns pure Sendable structs.

@ModelActor
actor ActivityComputer {

    private static let cal: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.firstWeekday = 2 // Monday
        return c
    }()

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
            // Load workouts and sets from SwiftData
            let workouts: [WorkoutRow]
            let sets: [SetRow]
            let templateMap: [String: String]
            var totalWorkoutCount = 0
            do {
                let ctx = ModelContext(modelContainer)
                let allWorkouts = try ctx.fetch(FetchDescriptor<Workout>())
                totalWorkoutCount = allWorkouts.count   // count ALL before any parsing filter
                workouts = allWorkouts.compactMap { w -> WorkoutRow? in
                    guard let d = Self.dateFmt.date(from: w.date) else { return nil }
                    // Parse UTC startTime; fall back to date midnight so window filters still work.
                    let st = Self.parseDateTime(w.startTime) ?? d
                    return WorkoutRow(date: d, startTime: st, durationMin: w.durationMin)
                }

                let allSets = try ctx.fetch(FetchDescriptor<WorkoutSet>())
                sets = allSets.compactMap { s -> SetRow? in
                    guard let d = Self.dateFmt.date(from: s.date) else { return nil }
                    return SetRow(
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

            // Load activity daily rows from GRDB
            let activityRows = try HealthRecordStore.shared.loadActivityDaily()

            // Compute all sections
            let workoutKPIs = computeWorkoutKPIs(workouts, totalWorkoutCount: totalWorkoutCount, dateStart: dateStart, dateEnd: dateEnd)
            let muscleRadar = computeMuscleRadar(
                sets, templateMap: templateMap,
                dateStart: dateStart, dateEnd: dateEnd,
                muscleTargets: muscleTargets
            )
            let volumeProgression = computeVolumeProgression(sets, templateMap: templateMap, dateEnd: dateEnd)
            let activityKPIs = computeActivityKPIs(activityRows, dateStart: dateStart, dateEnd: dateEnd)
            let energyTDEE = computeEnergyTDEE(activityRows, dateStart: dateStart, dateEnd: dateEnd)

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

    // MARK: - Internal row types

    private struct WorkoutRow {
        /// Local calendar date parsed from Workout.date.
        let date: Date
        /// UTC timestamp from Workout.startTime — used for window comparisons, mirrors Python's
        /// start_time after tz_convert(None).
        let startTime: Date
        let durationMin: Double
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

    private struct SetRow {
        let date: Date
        let exerciseTitle: String
        let setType: String
        let weightKg: Double
        let reps: Double
    }

    // MARK: - compute_workout_kpis (activity.py lines 314-360)

    private func computeWorkoutKPIs(
        _ workouts: [WorkoutRow],
        totalWorkoutCount: Int,
        dateStart: Date,
        dateEnd: Date
    ) -> WorkoutKPIs {
        guard totalWorkoutCount > 0 else {
            return WorkoutKPIs(
                totalWorkouts: 0, workoutsLastN: 0,
                avgDurationOverallMin: 0, avgDurationPriorMin: 0,
                priorDays: 0, deltaWorkouts: 0, deltaDurationMin: 0
            )
        }

        // total_workouts = len(df) — ALL workouts, no date filter
        let totalWorkouts = totalWorkoutCount
        let avgDurationOverall = workouts.isEmpty ? 0.0 : workouts.map(\.durationMin).mean()

        let rangeDays = Self.cal.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let periodLength = min(30, rangeDays)   // get_effective_days(30, rangeDays)

        // Workouts in [dateEnd - (periodLength-1) days .. dateEnd] by startTime — mirrors Python's
        // start_time field after tz_convert(None).
        let lastStart = dateEnd.addingTimeInterval(-Double(periodLength - 1) * 86_400)
        let workoutsLastN = workouts.filter { $0.startTime >= lastStart && $0.startTime <= dateEnd }.count

        // Prior window: [dateStart - periodLength .. dateStart] (mirrors df_prior in Python)
        let priorEnd = dateStart
        let priorStart = dateStart.addingTimeInterval(-Double(periodLength) * 86_400)
        let priorWorkouts = workouts.filter { $0.startTime >= priorStart && $0.startTime <= priorEnd }
        let avgPer30 = Double(priorWorkouts.count)
        let avgDurationPrior = priorWorkouts.isEmpty ? 0.0 : priorWorkouts.map(\.durationMin).mean()

        // delta_workouts = workouts_last30 - avg_per30
        // delta_duration = avg_duration_last30 - avg_duration_overall  (Python: last30 - overall)
        let deltaWorkouts = Double(workoutsLastN) - avgPer30
        let deltaDuration = avgDurationPrior - avgDurationOverall

        return WorkoutKPIs(
            totalWorkouts: totalWorkouts,
            workoutsLastN: workoutsLastN,
            avgDurationOverallMin: avgDurationOverall,
            avgDurationPriorMin: avgDurationPrior,
            priorDays: periodLength,
            deltaWorkouts: deltaWorkouts,
            deltaDurationMin: deltaDuration
        )
    }

    // MARK: - compute_muscle_radar (activity.py lines 217-278)

    private func computeMuscleRadar(
        _ sets: [SetRow],
        templateMap: [String: String],
        dateStart: Date,
        dateEnd: Date,
        muscleTargets: [String: Double]
    ) -> MuscleRadarData {
        let C = ActivityConstants.self

        // Exclude warmups; attach fine muscle; exclude Cardio/Other
        let enriched = sets.filter { $0.setType != "warmup" }.compactMap { s -> (SetRow, String)? in
            let fine = templateMap[s.exerciseTitle] ?? "Other"
            guard let coarse = C.hevyMuscleMap[fine] else { return nil }
            return (s, coarse)
        }

        let rangeDays = max(1, Self.cal.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1)
        let maxDays = min(rangeDays, C.maxRadarDays)

        // Current window: [end - maxDays .. end]
        let currentStart = dateEnd.addingTimeInterval(-Double(maxDays) * 86400)
        let effectiveCurrentStart = max(dateStart, currentStart)
        let currentSets = enriched.filter { $0.0.date >= effectiveCurrentStart && $0.0.date <= dateEnd }

        // Prior window: [currentStart - maxDays .. currentStart)
        let prevStart = currentStart.addingTimeInterval(-Double(maxDays) * 86400)
        let prevEnd = currentStart.addingTimeInterval(-86400) // one day before currentStart
        let priorSets = enriched.filter { $0.0.date >= prevStart && $0.0.date <= prevEnd }

        func setsByMuscle(_ enrichedSets: [(SetRow, String)]) -> [String: Int] {
            var counts: [String: Int] = Dictionary(uniqueKeysWithValues: C.radarMuscles.map { ($0, 0) })
            for (_, coarse) in enrichedSets {
                counts[coarse, default: 0] += 1
            }
            return counts
        }

        let currentCounts = setsByMuscle(currentSets)
        let previousCounts = setsByMuscle(priorSets)

        func ratiosForPeriod(counts: [String: Int], periodStart: Date, periodEnd: Date) -> [String: Double] {
            let days = max(1, Self.cal.dateComponents([.day], from: periodStart, to: periodEnd).day! + 1)
            var ratios: [String: Double] = [:]
            for muscle in C.radarMuscles {
                let actual = Double(counts[muscle] ?? 0)
                let weeklyTarget = muscleTargets[muscle] ?? 0
                guard weeklyTarget > 0 else { ratios[muscle] = 0; continue }
                let expected = weeklyTarget * Double(days) / 7.0
                ratios[muscle] = expected > 0 ? actual / expected : 0
            }
            return ratios
        }

        let currentRatios = ratiosForPeriod(counts: currentCounts, periodStart: effectiveCurrentStart, periodEnd: dateEnd)
        let prevPeriodEnd = prevEnd < prevStart ? prevStart : prevEnd
        let previousRatios = ratiosForPeriod(counts: previousCounts, periodStart: prevStart, periodEnd: prevPeriodEnd)

        return MuscleRadarData(
            currentCounts: currentCounts,
            previousCounts: previousCounts,
            currentRatios: currentRatios,
            previousRatios: previousRatios,
            daysUsed: maxDays
        )
    }

    // MARK: - compute_volume_progression (activity.py lines 281-311)

    private func computeVolumeProgression(
        _ sets: [SetRow],
        templateMap: [String: String],
        dateEnd: Date
    ) -> VolumeProgressionData {
        let C = ActivityConstants.self
        let nWeeks = C.volumeWeeks

        // Exclude warmups; compute volume; attach coarse muscle; exclude Cardio/Other
        let enriched: [(date: Date, coarse: String, volume: Double)] = sets.compactMap { s in
            guard s.setType != "warmup" else { return nil }
            let fine = templateMap[s.exerciseTitle] ?? "Other"
            guard let coarse = C.hevyMuscleMap[fine] else { return nil }
            let vol = s.weightKg * s.reps
            return (s.date, coarse, vol)
        }

        // Filter to last (nWeeks + 1) weeks from dateEnd
        let rangeStart = dateEnd.addingTimeInterval(-Double(nWeeks + 1) * 7 * 86400)
        let filtered = enriched.filter { $0.date >= rangeStart && $0.date <= dateEnd }

        // Group by ISO Monday-aligned week start
        func mondayOf(_ date: Date) -> Date {
            let comps = Self.cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return Self.cal.date(from: comps)!
        }

        // Aggregate volume by (weekStart, coarse muscle)
        var weekMuscleVol: [Date: [String: Double]] = [:]
        for row in filtered {
            let wk = mondayOf(row.date)
            weekMuscleVol[wk, default: [:]][row.coarse, default: 0] += row.volume
        }

        // Mirrors Python: weekly = weekly[sorted(weekly.columns)[-n_weeks:]]
        // → take last nWeeks week columns (not nWeeks+1); pct_change then drops the first,
        //   yielding nWeeks-1 visible comparison columns (5 for n_weeks=6).
        let allWeeks = weekMuscleVol.keys.sorted()
        let usedWeeks = Array(allWeeks.suffix(nWeeks))
        guard usedWeeks.count >= 2 else {
            return VolumeProgressionData(muscles: [], weekLabels: [], pctChange: [], weeklyVolume: [], priorVolume: [])
        }

        let muscles = C.radarMuscles

        // Build volume matrix: [muscle][week] for all usedWeeks
        let volMatrix: [[Double]] = muscles.map { muscle in
            usedWeeks.map { wk in weekMuscleVol[wk]?[muscle] ?? 0 }
        }

        // pct_change along week axis (axis=1 in pandas): compare each week to the prior column
        // Result has nWeeks columns (dropping the first week which was only used as prior)
        var pctMatrix: [[Double]] = []
        var currentVol: [[Double]] = []
        var priorVol: [[Double]] = []

        for mIdx in 0..<muscles.count {
            var pctRow: [Double] = []
            var curRow: [Double] = []
            var priorRow: [Double] = []
            for wkIdx in 1..<usedWeeks.count {
                let curr = volMatrix[mIdx][wkIdx]
                let prev = volMatrix[mIdx][wkIdx - 1]
                curRow.append(curr)
                priorRow.append(prev)
                // Mirrors Python pct_change() → replace(±inf) → pct_change[weekly==0] = 0:
                //   curr == 0   → 0  (Python forces zero-volume weeks to 0)
                //   prev == 0   → 100 (replaces +inf with 100)
                //   otherwise   → standard pct change rounded to 0 dp, NO clamp
                //                 (values above ±100% are valid and must pass through)
                if curr == 0 {
                    pctRow.append(0)
                } else if prev == 0 {
                    pctRow.append(100)
                } else {
                    let raw = (curr - prev) / prev * 100
                    pctRow.append(raw.rounded())
                }
            }
            pctMatrix.append(pctRow)
            currentVol.append(curRow)
            priorVol.append(priorRow)
        }

        // Build week labels for the display columns (skip first week)
        let displayWeeks = Array(usedWeeks.dropFirst())
        let labelFmt = DateFormatter()
        labelFmt.dateFormat = "dd.MM.yy"
        labelFmt.locale = Locale(identifier: "en_US_POSIX")
        let weekLabels = displayWeeks.map { wkStart -> String in
            let wkEnd = wkStart.addingTimeInterval(6 * 86400)
            return "\(labelFmt.string(from: wkStart)) - \(labelFmt.string(from: wkEnd))"
        }

        return VolumeProgressionData(
            muscles: muscles,
            weekLabels: weekLabels,
            pctChange: pctMatrix,
            weeklyVolume: currentVol,
            priorVolume: priorVol
        )
    }

    // MARK: - compute_activity_kpis (activity.py lines 174-202)

    private func computeActivityKPIs(
        _ rows: [HealthRecordStore.ActivityDailyRow],
        dateStart: Date,
        dateEnd: Date
    ) -> ActivityKPIs {
        let filtered = rows.filter { $0.date >= dateStart && $0.date <= dateEnd }

        let rangeDays = Self.cal.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let priorDays = min(30, rangeDays)

        guard !filtered.isEmpty else {
            return ActivityKPIs(avgSteps: 0, avgStandMin: 0, avgWalkingSpeed: 0, priorDays: priorDays)
        }

        // avg_steps: int(mean) — mirrors Python int(df["steps"].mean())
        let avgSteps = Int(filtered.map(\.steps).mean())
        // avg_stand_min: round(mean, 1)
        let avgStandMin = (filtered.map(\.standMin).mean() * 10).rounded() / 10
        // avg_walking_speed: round(mean, 2) — skip days with no walking_speed data (nil),
        // mirroring Python's pandas mean() which ignores NaN rows from the SQL AVG returning NULL.
        let speedValues = filtered.compactMap(\.walkingSpeedKmh)
        let avgWalkingSpeed: Double
        if speedValues.isEmpty {
            avgWalkingSpeed = 0.0
        } else {
            avgWalkingSpeed = (speedValues.mean() * 100).rounded() / 100
        }

        return ActivityKPIs(
            avgSteps: avgSteps,
            avgStandMin: avgStandMin,
            avgWalkingSpeed: avgWalkingSpeed,
            priorDays: priorDays
        )
    }

    // MARK: - compute_activity / energy TDEE (activity.py lines 161-171)

    private func computeEnergyTDEE(
        _ rows: [HealthRecordStore.ActivityDailyRow],
        dateStart: Date,
        dateEnd: Date
    ) -> EnergyTDEEData {
        let C = ActivityConstants.self

        // Filter to date range and apply quality filter (mirrors Python logic)
        let filtered = rows.filter { $0.date >= dateStart && $0.date <= dateEnd }
            .sorted { $0.date < $1.date }
            .filter { $0.basalEnergyKcal >= C.minBasalKcal && $0.activeEnergyKcal >= C.minActiveKcal }

        guard !filtered.isEmpty else {
            return EnergyTDEEData(points: [], effectiveDays: 0)
        }

        let activeValues = filtered.map(\.activeEnergyKcal)
        let window = C.rollingWindowDays
        let rolling = centeredRollingMean(activeValues, window: window)
        let effectiveDays = min(filtered.count, window)

        let points = filtered.enumerated().map { (i, row) in
            EnergyPoint(
                date: row.date,
                activeKcal: row.activeEnergyKcal,
                basalKcal: row.basalEnergyKcal,
                activeKcal7d: rolling[i].map { ($0 * 10).rounded() / 10 }
            )
        }

        return EnergyTDEEData(points: points, effectiveDays: effectiveDays)
    }

    // MARK: - Rolling window helpers (mirrors NutritionComputer)

    /// Centered rolling mean — mirrors pandas rolling(window, center=True, min_periods=1).mean().
    private func centeredRollingMean(_ values: [Double], window: Int) -> [Double?] {
        let n = values.count
        guard n > 0 else { return [] }
        let halfBefore = (window - 1) / 2
        let halfAfter = window / 2
        return (0..<n).map { i in
            let lo = max(0, i - halfBefore)
            let hi = min(n - 1, i + halfAfter)
            let slice = values[lo...hi]
            return slice.isEmpty ? nil : slice.reduce(0, +) / Double(slice.count)
        }
    }

}

// MARK: - Array helpers

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
