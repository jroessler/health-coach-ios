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

            let dailyMacros = prepareMacroKcalTimeseries(macrosFilteredPct)
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

    // MARK: - prepare_macro_kcal_timeseries (lines 167-184)

    private func prepareMacroKcalTimeseries(_ rows: [NutritionMacroAggregate], rollingWindowDays: Int = 7) -> DailyCaloriesMacrosData {
        guard !rows.isEmpty else { return DailyCaloriesMacrosData(points: [], effectiveDays: 0) }
        let sorted = rows.sorted { $0.date < $1.date }
        let kcals = sorted.map(\.calories)
        let rolling = centeredRollingMean(kcals, window: rollingWindowDays)
        let effectiveDays = min(sorted.count, rollingWindowDays)

        let points = sorted.enumerated().map { (i, row) in
            DailyMacroPoint(
                date: row.date,
                calories: row.calories,
                proteinKcal: row.calories * (row.protPct ?? 0) / 100,
                carbsKcal: row.calories * (row.carbPct ?? 0) / 100,
                fatKcal: row.calories * (row.fatPct ?? 0) / 100,
                proteinPct: row.protPct ?? 0,
                carbsPct: row.carbPct ?? 0,
                fatPct: row.fatPct ?? 0,
                rollingAvgKcal: rolling[i]
            )
        }
        return DailyCaloriesMacrosData(points: points, effectiveDays: effectiveDays)
    }

    // MARK: - compute_calorie_balance (lines 336-387)

    private func computeCalorieBalance(
        _ intakeRows: [IntakeRow], tdee tdeeRows: [TDEERow], scale scaleRows: [NutritionScaleAggregate],
        dateStart: Date, dateEnd: Date, minDate: Date
    ) -> CalorieBalanceData? {
        let intakeByDate = Dictionary(intakeRows.map { ($0.date, $0.intakeKcal) }, uniquingKeysWith: { $1 })
        let tdeeByDate = Dictionary(tdeeRows.map { ($0.date, $0.appleTDEE) }, uniquingKeysWith: { $1 })

        // Build merged date set for selected range
        let allDatesInRange = Set(intakeRows.map(\.date)).union(tdeeRows.map(\.date))
            .filter { $0 >= dateStart && $0 <= dateEnd }
            .sorted()

        guard !allDatesInRange.isEmpty else { return nil }

        // Empirical TDEE with lookback
        let numberOfDays = Self.cal.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let lookbackWindow = min(max(numberOfDays, 14), 30)
        var lookbackStart = Self.cal.date(byAdding: .day, value: -lookbackWindow, to: dateStart)!
        if lookbackStart < minDate { lookbackStart = minDate }

        let intakeFull = intakeRows.filter { $0.date >= lookbackStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }
        let scaleFull = scaleRows.filter { $0.date >= lookbackStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }

        // Nearest-weight assignment for full range
        let fullIntakeKcals = intakeFull.map(\.intakeKcal)
        let fullWeights: [Double?] = intakeFull.map { intake in
            nearestValue(in: scaleFull.compactMap { s in s.weightKg.map { (s.date, $0) } }, to: intake.date)
        }

        // diff(14) / 14
        let empWindow = NutritionConstants.empiricalRollingWindowDays
        var deltaKgPerDay: [Double?] = Array(repeating: nil, count: intakeFull.count)
        for i in empWindow..<intakeFull.count {
            if let w1 = fullWeights[i], let w0 = fullWeights[i - empWindow] {
                deltaKgPerDay[i] = (w1 - w0) / Double(empWindow)
            }
        }

        // rolling(14, min_periods=7).mean on intake
        let intake14dAvg = rollingMean(fullIntakeKcals, window: empWindow, minPeriods: empWindow / 2)

        // empirical_tdee = intake_14d_avg - delta_kg_per_day.fillna(0) * 7700
        var empiricalTDEE: [Double?] = Array(repeating: nil, count: intakeFull.count)
        for i in 0..<intakeFull.count {
            if let avg = intake14dAvg[i] {
                let delta = deltaKgPerDay[i] ?? 0
                empiricalTDEE[i] = avg - delta * NutritionConstants.kcalPerKgBodyWeight
            }
        }
        // ffill then bfill
        ffillBfill(&empiricalTDEE)

        // Map empirical TDEE back to selected range dates
        var empTDEEByDate: [Date: Double] = [:]
        for (i, row) in intakeFull.enumerated() {
            if let v = empiricalTDEE[i] { empTDEEByDate[row.date] = v }
        }
        // ffill/bfill within selected range
        var empValuesForRange: [Double?] = allDatesInRange.map { empTDEEByDate[$0] }
        ffillBfill(&empValuesForRange)

        // Build balance points
        let rollingWindow = NutritionConstants.rollingWindowDays
        var balanceAppleRaw: [Double?] = []
        for d in allDatesInRange {
            let intake = intakeByDate[d]
            let apple = tdeeByDate[d]
            if let i = intake, let a = apple {
                balanceAppleRaw.append((i - a).rounded())
            } else {
                balanceAppleRaw.append(nil)
            }
        }

        var balanceEmpRaw: [Double?] = []
        for (idx, d) in allDatesInRange.enumerated() {
            let intake = intakeByDate[d]
            if let i = intake, let emp = empValuesForRange[idx] {
                balanceEmpRaw.append((i - emp).rounded())
            } else {
                balanceEmpRaw.append(nil)
            }
        }

        let balanceApple7d = centeredRollingMeanOptional(balanceAppleRaw, window: rollingWindow)
        let balanceEmp7d = centeredRollingMeanOptional(balanceEmpRaw, window: rollingWindow)
        let effectiveDays = min(allDatesInRange.count, rollingWindow)

        let points = allDatesInRange.enumerated().map { (i, d) in
            CalorieBalancePoint(
                date: d,
                balanceApple: balanceAppleRaw[i],
                balanceApple7d: balanceApple7d[i].map { $0.rounded() },
                balanceEmpirical7d: balanceEmp7d[i].map { $0.rounded() }
            )
        }
        return CalorieBalanceData(points: points, effectiveDays: effectiveDays)
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

        let weightRolling = centeredRollingMeanOptional(weights, window: window)
        let fatRolling = centeredRollingMeanOptional(fats, window: window)
        let ffmRolling = centeredRollingMeanOptional(ffms, window: window)
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
        let filtered = scale.filter { $0.date >= dateStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }
        guard filtered.count >= 2 else { return nil }

        let weeklyGroups = groupByMondayWeek(filtered.map { ($0.date, $0.weightKg ?? 0, $0.fatPercent) })
        guard weeklyGroups.count >= 2 else { return nil }

        let weeklyMeans: [(weekStart: Date, meanWeight: Double, meanFat: Double?)] = weeklyGroups.map { group in
            let weights = group.values.map(\.weight)
            let fats = group.values.compactMap(\.bf)
            return (
                group.weekStart,
                (weights.mean() * 100).rounded() / 100,
                fats.isEmpty ? nil : (fats.mean() * 100).rounded() / 100
            )
        }

        var points: [WeeklyLossPoint] = []
        let labelFmt = DateFormatter()
        labelFmt.dateFormat = "MMM dd"
        labelFmt.locale = Locale(identifier: "en_US_POSIX")

        for i in 0..<weeklyMeans.count {
            let deltaWt: Double? = i > 0 ? ((weeklyMeans[i].meanWeight - weeklyMeans[i-1].meanWeight) * 100).rounded() / 100 : nil
            var deltaBf: Double?
            if i > 0, let f1 = weeklyMeans[i].meanFat, let f0 = weeklyMeans[i-1].meanFat {
                deltaBf = ((f1 - f0) * 100).rounded() / 100
            }
            points.append(WeeklyLossPoint(
                weekStart: weeklyMeans[i].weekStart,
                weekLabel: labelFmt.string(from: weeklyMeans[i].weekStart),
                deltaWeightKg: deltaWt,
                deltaBodyFatPct: deltaBf
            ))
        }
        return WeeklyLossRateData(points: points)
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

    // MARK: - Helpers: rolling windows

    /// Centered rolling mean with min_periods=1 (mirrors pandas center=True, min_periods=1).
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

    private func centeredRollingMeanOptional(_ values: [Double?], window: Int) -> [Double?] {
        let n = values.count
        guard n > 0 else { return [] }
        let halfBefore = (window - 1) / 2
        let halfAfter = window / 2
        return (0..<n).map { i in
            let lo = max(0, i - halfBefore)
            let hi = min(n - 1, i + halfAfter)
            let slice = values[lo...hi].compactMap { $0 }
            return slice.isEmpty ? nil : slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Left-aligned rolling mean (standard pandas default without center).
    private func rollingMean(_ values: [Double], window: Int, minPeriods: Int) -> [Double?] {
        let n = values.count
        return (0..<n).map { i in
            let start = max(0, i - window + 1)
            let slice = Array(values[start...i])
            return slice.count >= minPeriods ? slice.reduce(0, +) / Double(slice.count) : nil
        }
    }

    /// Forward-fill then backward-fill nil values.
    private func ffillBfill(_ arr: inout [Double?]) {
        // Forward fill
        for i in 1..<arr.count {
            if arr[i] == nil { arr[i] = arr[i-1] }
        }
        // Backward fill
        for i in stride(from: arr.count - 2, through: 0, by: -1) {
            if arr[i] == nil { arr[i] = arr[i+1] }
        }
    }

    /// Find nearest value by date from a sorted list.
    private func nearestValue(in entries: [(Date, Double)], to target: Date) -> Double? {
        guard !entries.isEmpty else { return nil }
        var best = entries[0]
        var bestDist = abs(target.timeIntervalSince(entries[0].0))
        for e in entries.dropFirst() {
            let dist = abs(target.timeIntervalSince(e.0))
            if dist < bestDist { best = e; bestDist = dist }
        }
        return best.1
    }

    // MARK: - Helpers: week grouping

    private struct WeekGroup {
        let weekStart: Date
        var values: [(weight: Double, bf: Double?)]
    }

    /// Group rows by ISO Monday-aligned week start (mirrors pandas dt.to_period("W").dt.start_time).
    private func groupByMondayWeek(_ rows: [(date: Date, weight: Double, bf: Double?)]) -> [WeekGroup] {
        var groups: [Date: WeekGroup] = [:]
        for row in rows {
            let weekStart = Self.mondayOfWeek(containing: row.date)
            var group = groups[weekStart] ?? WeekGroup(weekStart: weekStart, values: [])
            group.values.append((weight: row.weight, bf: row.bf))
            groups[weekStart] = group
        }
        return groups.values.sorted { $0.weekStart < $1.weekStart }
    }

    /// Get the Monday at or before the given date.
    private static func mondayOfWeek(containing date: Date) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)!
    }
}

// MARK: - Array helpers

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

