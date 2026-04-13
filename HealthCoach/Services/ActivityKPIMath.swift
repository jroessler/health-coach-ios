import Foundation

// Pure activity KPI pipeline — shared by `ActivityComputer` and unit tests.
// Mirrors `docs/activity-computations.md` and `activity.py`.

struct ActivityWorkoutInput: Sendable {
    let date: Date
    let startTime: Date
    let durationMin: Double
}

struct ActivitySetInput: Sendable {
    let date: Date
    let exerciseTitle: String
    let setType: String
    let weightKg: Double
    let reps: Double
}

enum ActivityKPIMath {

    /// Same configuration as the original `ActivityComputer` calendar.
    static let activityCalendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.firstWeekday = 2 // Monday
        return c
    }()

    // MARK: - Workout KPIs

    static func computeWorkoutKPIs(
        workouts: [ActivityWorkoutInput],
        totalWorkoutCount: Int,
        dateStart: Date,
        dateEnd: Date
    ) -> WorkoutKPIs {
        guard totalWorkoutCount > 0 else {
            return WorkoutKPIs(
                totalWorkouts: 0, workoutsLastN: 0,
                avgDurationOverallMin: 0, avgDurationLastNMin: 0, avgDurationPriorMin: 0,
                priorDays: 0, deltaWorkouts: 0, deltaDurationMin: 0
            )
        }

        let totalWorkouts = totalWorkoutCount
        let avgDurationOverall = workouts.isEmpty ? 0.0 : workouts.map(\.durationMin).mean()

        let rangeDays = Self.activityCalendar.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let periodLength = min(30, rangeDays)

        let endDay = Self.activityCalendar.startOfDay(for: dateEnd)
        let lastStart = endDay.addingTimeInterval(-Double(periodLength - 1) * 86_400)
        let lastDayEndExclusive = Self.activityCalendar.date(byAdding: .day, value: 1, to: endDay)!
        let lastNWorkouts = workouts.filter { $0.startTime >= lastStart && $0.startTime < lastDayEndExclusive }
        let workoutsLastN = lastNWorkouts.count

        let priorEnd = dateStart
        let priorStart = dateStart.addingTimeInterval(-Double(periodLength) * 86_400)
        let priorWorkouts = workouts.filter { $0.startTime >= priorStart && $0.startTime <= priorEnd }
        let avgPer30 = Double(priorWorkouts.count)
        let avgDurationPrior = priorWorkouts.isEmpty ? 0.0 : priorWorkouts.map(\.durationMin).mean()
        let avgDurationLastN = lastNWorkouts.isEmpty ? 0.0 : lastNWorkouts.map(\.durationMin).mean()

        let deltaWorkouts = Double(workoutsLastN) - avgPer30
        let deltaDuration = avgDurationLastN - avgDurationPrior

        return WorkoutKPIs(
            totalWorkouts: totalWorkouts,
            workoutsLastN: workoutsLastN,
            avgDurationOverallMin: avgDurationOverall,
            avgDurationLastNMin: avgDurationLastN,
            avgDurationPriorMin: avgDurationPrior,
            priorDays: periodLength,
            deltaWorkouts: deltaWorkouts,
            deltaDurationMin: deltaDuration
        )
    }

    // MARK: - Muscle radar

    static func computeMuscleRadar(
        _ sets: [ActivitySetInput],
        templateMap: [String: String],
        dateStart: Date,
        dateEnd: Date,
        muscleTargets: [String: Double]
    ) -> MuscleRadarData {
        let C = ActivityConstants.self

        let enriched = sets.filter { $0.setType != "warmup" }.compactMap { s -> (ActivitySetInput, String)? in
            let fine = templateMap[s.exerciseTitle] ?? "Other"
            guard let coarse = C.hevyMuscleMap[fine] else { return nil }
            return (s, coarse)
        }

        let rangeDays = max(1, Self.activityCalendar.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1)
        let maxDays = min(rangeDays, C.maxRadarDays)

        let currentStart = dateEnd.addingTimeInterval(-Double(maxDays) * 86400)
        let effectiveCurrentStart = max(dateStart, currentStart)
        let currentSets = enriched.filter { $0.0.date >= effectiveCurrentStart && $0.0.date <= dateEnd }

        func setsByMuscle(_ enrichedSets: [(ActivitySetInput, String)]) -> [String: Int] {
            var counts: [String: Int] = Dictionary(uniqueKeysWithValues: C.radarMuscles.map { ($0, 0) })
            for (_, coarse) in enrichedSets {
                counts[coarse, default: 0] += 1
            }
            return counts
        }

        let currentCounts = setsByMuscle(currentSets)

        func ratiosForPeriod(counts: [String: Int], periodStart: Date, periodEnd: Date) -> [String: Double] {
            let days = max(1, Self.activityCalendar.dateComponents([.day], from: periodStart, to: periodEnd).day! + 1)
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

        return MuscleRadarData(
            currentCounts: currentCounts,
            currentRatios: currentRatios,
            daysUsed: maxDays
        )
    }

    // MARK: - Volume progression

    static func computeVolumeProgression(
        _ sets: [ActivitySetInput],
        templateMap: [String: String],
        dateEnd: Date
    ) -> VolumeProgressionData {
        let C = ActivityConstants.self
        let nWeeks = C.volumeWeeks

        let enriched: [(date: Date, coarse: String, volume: Double)] = sets.compactMap { s in
            guard s.setType != "warmup" else { return nil }
            let fine = templateMap[s.exerciseTitle] ?? "Other"
            guard let coarse = C.hevyMuscleMap[fine] else { return nil }
            let vol = s.weightKg * s.reps
            return (s.date, coarse, vol)
        }

        let rangeStart = dateEnd.addingTimeInterval(-Double(nWeeks + 1) * 7 * 86400)
        let filtered = enriched.filter { $0.date >= rangeStart && $0.date <= dateEnd }

        func mondayOf(_ date: Date) -> Date {
            let comps = Self.activityCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return Self.activityCalendar.date(from: comps)!
        }

        var weekMuscleVol: [Date: [String: Double]] = [:]
        for row in filtered {
            let wk = mondayOf(row.date)
            weekMuscleVol[wk, default: [:]][row.coarse, default: 0] += row.volume
        }

        let allWeeks = weekMuscleVol.keys.sorted()
        let usedWeeks = Array(allWeeks.suffix(nWeeks))
        guard usedWeeks.count >= 2 else {
            return VolumeProgressionData(muscles: [], weekLabels: [], pctChange: [], weeklyVolume: [], priorVolume: [])
        }

        let muscles = C.radarMuscles

        let volMatrix: [[Double]] = muscles.map { muscle in
            usedWeeks.map { wk in weekMuscleVol[wk]?[muscle] ?? 0 }
        }

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

    // MARK: - Activity KPIs (steps / stand / walk)

    static func computeActivityKPIs(
        _ rows: [HealthRecordStore.ActivityDailyRow],
        dateStart: Date,
        dateEnd: Date
    ) -> ActivityKPIs {
        let filtered = rows.filter { $0.date >= dateStart && $0.date <= dateEnd }

        let rangeDays = Self.activityCalendar.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let priorDays = min(30, rangeDays)

        guard !filtered.isEmpty else {
            return ActivityKPIs(avgSteps: 0, avgStandMin: 0, avgWalkingSpeed: 0, priorDays: priorDays)
        }

        let avgSteps = Int(filtered.map(\.steps).mean())
        let avgStandMin = (filtered.map(\.standMin).mean() * 10).rounded() / 10
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

    // MARK: - Energy TDEE

    static func computeEnergyTDEE(
        _ rows: [HealthRecordStore.ActivityDailyRow],
        dateStart: Date,
        dateEnd: Date
    ) -> EnergyTDEEData {
        let C = ActivityConstants.self

        let filtered = rows.filter { $0.date >= dateStart && $0.date <= dateEnd }
            .sorted { $0.date < $1.date }
            .filter { $0.basalEnergyKcal >= C.minBasalKcal && $0.activeEnergyKcal >= C.minActiveKcal }

        guard !filtered.isEmpty else {
            return EnergyTDEEData(points: [], effectiveDays: 0)
        }

        let activeValues = filtered.map(\.activeEnergyKcal)
        let window = C.rollingWindowDays
        let rolling = NutritionKPIMath.centeredRollingMean(activeValues, window: window)
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
}

// MARK: - Array helpers

extension Array where Element == Double {
    fileprivate func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
