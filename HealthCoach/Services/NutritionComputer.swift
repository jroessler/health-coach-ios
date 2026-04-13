import Foundation
import SwiftData

// Mirrors health/app/services/nutrition.py — all formulas ported 1:1.
// Runs off the main thread via @ModelActor; returns pure Sendable structs.

@ModelActor
actor NutritionComputer {

    private static let cal = Calendar(identifier: .iso8601)
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()
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

    // MARK: - Public entry point
    //
    // Data loading is split into phases, each using a temporary ModelContext.
    // When a phase completes, its context (and all cached SwiftData objects)
    // is released before the next phase starts. This keeps peak memory
    // proportional to the largest single phase rather than the sum of all data.

    func compute(dateStart: Date, dateEnd: Date) -> NutritionSnapshot? {
        do {
            // Phase 1: NutritionEntry → lightweight structs, then release model objects
            let macrosRaw: [NutritionMacroAggregate]
            let intakeRows: [IntakeRow]
            let nutritionLog: [NutritionLogRow]
            do {
                let ctx = ModelContext(modelContainer)
                let entries = try ctx.fetch(FetchDescriptor<NutritionEntry>())
                macrosRaw = loadMacros(entries)
                intakeRows = extractIntakeRows(entries)
                nutritionLog = loadNutritionLog(entries)
            }

            guard !macrosRaw.isEmpty else { return nil }

            // Phase 2: Scale data via GRDB SQL aggregation (GROUP BY date)
            let store = HealthRecordStore.shared
            let scale: [NutritionScaleAggregate] = try store.loadScale().map {
                NutritionScaleAggregate(date: $0.date, weightKg: $0.weightKg, fatPercent: $0.fatPercent)
            }

            // Phase 3: TDEE via GRDB SQL aggregation (GROUP BY date, SUM)
            let tdeeRows: [TDEERow] = try store.loadDailyTDEE().map {
                TDEERow(date: $0.date, appleTDEE: $0.appleTDEE)
            }

            // Phase 4: Workouts — typically a few hundred at most
            let workoutEntries: [WorkoutEntry]
            do {
                let ctx = ModelContext(modelContainer)
                let workouts = try ctx.fetch(FetchDescriptor<Workout>())
                workoutEntries = loadWorkoutEntries(workouts)
            }

            // Phase 5: Pure computation — mirrors Python: filter_macros(macros) then compute_macro_pct(filtered)
            let macrosFilteredRaw = NutritionKPIMath.filterMacros(macrosRaw, dateStart: dateStart, dateEnd: dateEnd)
            let macrosFilteredPct = NutritionKPIMath.computeMacroPct(macrosFilteredRaw)

            let kpis = NutritionKPIMath.computeKPIValues(
                macrosFilteredPct, scale: scale, dateStart: dateStart, dateEnd: dateEnd, calendar: Self.cal
            )
            let macroTargets = NutritionKPIMath.computeMacroPctAverages(macrosFilteredPct)

            let dailyMacros = NutritionKPIMath.prepareDailyCaloriesMacrosData(macrosFilteredPct)
            let calorieBalance = computeCalorieBalance(
                intakeRows, tdee: tdeeRows, scale: scale,
                dateStart: dateStart, dateEnd: dateEnd,
                minDate: macrosRaw.map(\.date).min() ?? dateStart
            )
            let weightTrends = computeScaleMetrics(scale, dateStart: dateStart, dateEnd: dateEnd)
            let weeklyLoss = computeWeeklyLossRates(scale, dateStart: dateStart, dateEnd: dateEnd)

            let (prePoints, postPoints) = computeWorkoutNutrition(
                nutritionLog, workouts: workoutEntries, dateStart: dateStart, dateEnd: dateEnd
            )

            let avgWt = computeAvgWeightKg(scale)
            let preTargets: PreWorkoutTargets? = avgWt.map {
                PreWorkoutTargets(proteinTargetG: $0 * 0.3, carbsTargetG: $0 * 0.5)
            }

            return NutritionSnapshot(
                kpis: kpis,
                macroTargets: macroTargets,
                dailyCaloriesMacros: dailyMacros,
                calorieBalance: calorieBalance,
                weightTrends: weightTrends,
                weeklyLossRates: weeklyLoss,
                preWorkout: prePoints,
                postWorkout: postPoints,
                avgWeightKg: avgWt,
                preWorkoutTargets: preTargets
            )
        } catch {
            return nil
        }
    }

    // MARK: - Internal row types

    private struct IntakeRow {
        let date: Date
        var intakeKcal: Double
    }

    private struct TDEERow {
        let date: Date
        var appleTDEE: Double
    }

    private struct NutritionLogRow {
        let startDate: Date
        let dateOnly: Date
        let energyKcal: Double
        let proteinG: Double
        let carbsG: Double
        let fatTotalG: Double
    }

    private struct WorkoutEntry {
        let startTime: Date
        let endTime: Date
        let dateOnly: Date
    }

    // MARK: - Loading (mirrors SQL queries in nutrition.py)

    private func loadMacros(_ entries: [NutritionEntry]) -> [NutritionMacroAggregate] {
        var byDate: [Date: NutritionMacroAggregate] = [:]
        for e in entries {
            guard let d = Self.dateFmt.date(from: e.date) else { continue }
            var row = byDate[d] ?? NutritionMacroAggregate(date: d, calories: 0, proteinG: 0, carbsG: 0, fatG: 0)
            row.calories += e.energyKcal ?? 0
            row.proteinG += e.proteinG ?? 0
            row.carbsG += e.carbsG ?? 0
            row.fatG += e.fatTotalG ?? 0
            byDate[d] = row
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    private func extractIntakeRows(_ entries: [NutritionEntry]) -> [IntakeRow] {
        var intakeByDate: [Date: Double] = [:]
        for e in entries {
            guard let kcal = e.energyKcal, let d = Self.dateFmt.date(from: e.date) else { continue }
            intakeByDate[d, default: 0] += kcal
        }
        return intakeByDate.map { IntakeRow(date: $0.key, intakeKcal: $0.value) }.sorted { $0.date < $1.date }
    }

    private func loadNutritionLog(_ entries: [NutritionEntry]) -> [NutritionLogRow] {
        entries.compactMap { e in
            guard let sd = Self.parseDateTime(e.startDate),
                  let d = Self.dateFmt.date(from: e.date) else { return nil }
            return NutritionLogRow(
                startDate: sd, dateOnly: d,
                energyKcal: e.energyKcal ?? 0,
                proteinG: e.proteinG ?? 0,
                carbsG: e.carbsG ?? 0,
                fatTotalG: e.fatTotalG ?? 0
            )
        }.sorted { $0.startDate < $1.startDate }
    }

    private func loadWorkoutEntries(_ workouts: [Workout]) -> [WorkoutEntry] {
        workouts.compactMap { w in
            guard let st = Self.parseDateTime(w.startTime),
                  let et = Self.parseDateTime(w.endTime),
                  let d = Self.dateFmt.date(from: w.date) else { return nil }
            return WorkoutEntry(startTime: st, endTime: et, dateOnly: d)
        }.sorted { $0.startTime < $1.startTime }
    }

    private static func parseDateTime(_ s: String) -> Date? {
        isoFmt.date(from: s) ?? isoFmtNoFrac.date(from: s)
    }

    // MARK: - compute_calorie_balance (lines 336-387)

    private func computeCalorieBalance(
        _ intakeRows: [IntakeRow], tdee tdeeRows: [TDEERow], scale scaleRows: [NutritionScaleAggregate],
        dateStart: Date, dateEnd: Date, minDate: Date
    ) -> CalorieBalanceData? {
        NutritionKPIMath.computeCalorieBalance(
            intakeRows: intakeRows.map { NutritionKPIMath.CalorieBalanceIntakeRow(date: $0.date, intakeKcal: $0.intakeKcal) },
            tdeeRows: tdeeRows.map { NutritionKPIMath.CalorieBalanceTDEERow(date: $0.date, appleTDEE: $0.appleTDEE) },
            scaleRows: scaleRows,
            dateStart: dateStart,
            dateEnd: dateEnd,
            minDate: minDate,
            calendar: Self.cal
        )
    }

    // MARK: - compute_scale_metrics (lines 390-405)

    private func computeScaleMetrics(_ scale: [NutritionScaleAggregate], dateStart: Date, dateEnd: Date) -> WeightTrendsData? {
        let filtered = scale.filter { $0.date >= dateStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }
        guard !filtered.isEmpty else { return nil }

        let window = NutritionConstants.rollingWindowDays
        let weights = filtered.map(\.weightKg)
        let fats = filtered.map(\.fatPercent)
        let ffms: [Double?] = filtered.map { row in
            guard let w = row.weightKg, let f = row.fatPercent else { return nil }
            return (w * (1 - f / 100) * 100).rounded() / 100
        }

        let weightRolling = NutritionKPIMath.centeredRollingMeanOptional(weights, window: window)
        let fatRolling = NutritionKPIMath.centeredRollingMeanOptional(fats, window: window)
        let ffmRolling = NutritionKPIMath.centeredRollingMeanOptional(ffms, window: window)
        let effectiveDays = min(filtered.count, window)

        let points = filtered.enumerated().map { (i, row) in
            WeightTrendPoint(
                date: row.date,
                weightRolling7d: weightRolling[i],
                fatPctRolling7d: fatRolling[i],
                ffmRolling7d: ffmRolling[i]
            )
        }
        return WeightTrendsData(points: points, effectiveDays: effectiveDays)
    }

    // MARK: - compute_weekly_loss_rates (lines 408-421)

    private func computeWeeklyLossRates(_ scale: [NutritionScaleAggregate], dateStart: Date, dateEnd: Date) -> WeeklyLossRateData? {
        NutritionKPIMath.computeWeeklyLossRates(scale: scale, dateStart: dateStart, dateEnd: dateEnd)
    }

    // MARK: - compute_workout_nutrition (lines 521-579)

    private func computeWorkoutNutrition(
        _ nutrition: [NutritionLogRow], workouts: [WorkoutEntry],
        dateStart: Date, dateEnd: Date
    ) -> ([PreWorkoutPoint], [PostWorkoutPoint]) {
        let startDay = Self.cal.startOfDay(for: dateStart)
        let endDay = Self.cal.startOfDay(for: dateEnd)

        let filteredNutrition = nutrition.filter { $0.dateOnly >= startDay && $0.dateOnly <= endDay }
        let filteredWorkouts = workouts.filter { $0.dateOnly >= startDay && $0.dateOnly <= endDay }

        var prePoints: [PreWorkoutPoint] = []
        var postPoints: [PostWorkoutPoint] = []

        for w in filteredWorkouts {
            let preWindowStart = w.startTime.addingTimeInterval(-NutritionConstants.preWorkoutWindowHours * 3600)
            let postWindowEnd = w.endTime.addingTimeInterval(NutritionConstants.postWorkoutWindowHours * 3600)

            let pre = filteredNutrition.filter { $0.startDate >= preWindowStart && $0.startDate <= w.startTime }
            let post = filteredNutrition.filter { $0.startDate >= w.endTime && $0.startDate <= postWindowEnd }

            if !pre.isEmpty {
                let totalCal = pre.map(\.energyKcal).reduce(0, +)
                let totalProt = pre.map(\.proteinG).reduce(0, +)
                let totalCarbs = pre.map(\.carbsG).reduce(0, +)
                let totalFat = pre.map(\.fatTotalG).reduce(0, +)
                let lastPreTimestamp = pre.last!.startDate
                let minsBefore = Int(w.startTime.timeIntervalSince(lastPreTimestamp)) / 60

                let timing = classifyPreWorkoutTiming(minsBefore)

                prePoints.append(PreWorkoutPoint(
                    workoutDate: w.dateOnly,
                    minutesBefore: minsBefore,
                    proteinG: totalProt,
                    carbsG: totalCarbs,
                    calories: totalCal,
                    fatG: totalFat,
                    timingQuality: timing
                ))
            }

            if !post.isEmpty {
                let totalCal = post.map(\.energyKcal).reduce(0, +)
                let totalProt = post.map(\.proteinG).reduce(0, +)
                let totalCarbs = post.map(\.carbsG).reduce(0, +)
                let totalFat = post.map(\.fatTotalG).reduce(0, +)
                let firstPostTimestamp = post.first!.startDate
                let minsAfter = Int(firstPostTimestamp.timeIntervalSince(w.endTime)) / 60

                let quadrant = classifyPostWorkoutQuadrant(minutesAfter: minsAfter, proteinG: totalProt)

                postPoints.append(PostWorkoutPoint(
                    workoutDate: w.dateOnly,
                    minutesAfter: minsAfter,
                    proteinG: totalProt,
                    carbsG: totalCarbs,
                    calories: totalCal,
                    fatG: totalFat,
                    quadrant: quadrant
                ))
            }
        }
        return (prePoints, postPoints)
    }

    // MARK: - compute_avg_weight_kg (lines 257-261)

    private func computeAvgWeightKg(_ scale: [NutritionScaleAggregate]) -> Double? {
        let weights = scale.compactMap(\.weightKg)
        guard !weights.isEmpty else { return nil }
        return weights.mean()
    }

    // MARK: - classify_pre_workout_timing (lines 268-282)

    private func classifyPreWorkoutTiming(_ minutesBefore: Int) -> WorkoutTimingQuality {
        if minutesBefore >= NutritionConstants.preWorkoutTimingGoodMin &&
           minutesBefore <= NutritionConstants.preWorkoutTimingGoodMax {
            return .good
        } else if minutesBefore < NutritionConstants.preWorkoutTimingGoodMin {
            return .ok
        } else {
            return .bad
        }
    }

    // MARK: - classify_post_workout_quadrant (lines 294-311)

    private func classifyPostWorkoutQuadrant(minutesAfter: Int, proteinG: Double) -> WorkoutTimingQuality {
        let inTime = minutesAfter <= NutritionConstants.postWorkoutTimingTargetMin
        let enoughProt = proteinG >= NutritionConstants.proteinPostWorkoutTargetG
        if inTime && enoughProt { return .good }
        if !inTime && !enoughProt { return .bad }
        return .ok
    }

}

// MARK: - Array helpers

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

