import Foundation

// Pure nutrition KPI pipeline (filter_macros → compute_macro_pct → compute_kpi_values).
// Shared with NutritionComputer and unit tests.

struct NutritionMacroAggregate: Sendable {
    let date: Date
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var protPct: Double?
    var carbPct: Double?
    var fatPct: Double?

    init(
        date: Date,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        protPct: Double? = nil,
        carbPct: Double? = nil,
        fatPct: Double? = nil
    ) {
        self.date = date
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.protPct = protPct
        self.carbPct = carbPct
        self.fatPct = fatPct
    }
}

struct NutritionScaleAggregate: Sendable {
    let date: Date
    var weightKg: Double?
    var fatPercent: Double?
}

enum NutritionKPIMath {

    static func filterMacros(
        _ rows: [NutritionMacroAggregate],
        dateStart: Date,
        dateEnd: Date
    ) -> [NutritionMacroAggregate] {
        rows.filter {
            $0.date >= dateStart && $0.date <= dateEnd && $0.calories >= NutritionConstants.minCaloriesForFiltering
        }
    }

    static func computeMacroPct(_ rows: [NutritionMacroAggregate]) -> [NutritionMacroAggregate] {
        rows.map { row in
            var r = row
            if row.calories > 0 {
                r.protPct = (row.proteinG * NutritionConstants.proteinKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
                r.carbPct = (row.carbsG * NutritionConstants.carbsKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
                r.fatPct = (row.fatG * NutritionConstants.fatKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
            }
            return r
        }
    }

    static func computeKPIValues(
        _ macrosPct: [NutritionMacroAggregate],
        scale: [NutritionScaleAggregate],
        dateStart: Date,
        dateEnd: Date,
        calendar: Calendar
    ) -> NutritionKPIs {
        let macrosInRange = macrosPct.filter { $0.date >= dateStart && $0.date <= dateEnd }
        let scaleInRange = scale.filter { $0.date >= dateStart && $0.date <= dateEnd && $0.weightKg != nil }
            .sorted { $0.date < $1.date }
        let scaleBeforeRange = scale.filter { $0.date < dateStart && $0.weightKg != nil }
            .sorted { $0.date < $1.date }

        let last7Start = max(dateStart, calendar.date(byAdding: .day, value: -6, to: dateEnd)!)
        let last7 = macrosInRange.filter { $0.date >= last7Start && $0.date <= dateEnd }
        let avgCalories7d = last7.isEmpty ? 0.0 : last7.map(\.calories).mean()
        let avgProtein7d = last7.isEmpty ? 0.0 : last7.map(\.proteinG).mean()

        var bfChange: Double?
        var wtChange: Double?

        if !scaleInRange.isEmpty {
            let bfRows = scaleInRange.filter { $0.fatPercent != nil }
            if bfRows.count >= 2 {
                bfChange = ((bfRows.last!.fatPercent! - bfRows.first!.fatPercent!) * 10).rounded() / 10
            }
            if scaleInRange.count >= 2 {
                wtChange = ((scaleInRange.last!.weightKg! - scaleInRange.first!.weightKg!) * 10).rounded() / 10
            }
        }

        // Prefer latest weigh-in inside the chart range; else most recent before rangeStart (no default 75 kg).
        let weightForProteinPerKg = scaleInRange.last?.weightKg ?? scaleBeforeRange.last?.weightKg
        let proteinPerKg: Double?
        if let w = weightForProteinPerKg, w > 0 {
            proteinPerKg = (avgProtein7d / w * 100).rounded() / 100
        } else {
            proteinPerKg = nil
        }

        return NutritionKPIs(
            last7dAvgKcal: avgCalories7d,
            totalBodyFatChange: bfChange,
            totalWeightChange: wtChange,
            sevenDayProteinPerKg: proteinPerKg
        )
    }

    // MARK: - compute_macro_pct_averages (Macro Overview — mean of daily macro %)

    static func computeMacroPctAverages(_ rows: [NutritionMacroAggregate]) -> MacroTargetData {
        guard !rows.isEmpty else { return MacroTargetData(avgProteinPct: nil, avgCarbsPct: nil, avgFatPct: nil) }
        let prots = rows.compactMap(\.protPct)
        let carbs = rows.compactMap(\.carbPct)
        let fats = rows.compactMap(\.fatPct)
        return MacroTargetData(
            avgProteinPct: prots.isEmpty ? nil : prots.mean(),
            avgCarbsPct: carbs.isEmpty ? nil : carbs.mean(),
            avgFatPct: fats.isEmpty ? nil : fats.mean()
        )
    }

    // MARK: - Daily Calories + Macros chart (centered rolling kcal)

    /// Centered rolling mean — mirrors pandas `rolling(window, center=True, min_periods=1).mean()`.
    static func centeredRollingMean(_ values: [Double], window: Int) -> [Double?] {
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

    /// Sorted macro days → daily chart points with rolling average kcal (consecutive filtered days, not calendar holes).
    static func prepareDailyCaloriesMacrosData(
        _ rows: [NutritionMacroAggregate],
        rollingWindowDays: Int = NutritionConstants.rollingWindowDays
    ) -> DailyCaloriesMacrosData {
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

    // MARK: - Calorie balance (Apple + empirical TDEE)

    struct CalorieBalanceIntakeRow: Sendable {
        let date: Date
        let intakeKcal: Double
    }

    struct CalorieBalanceTDEERow: Sendable {
        let date: Date
        let appleTDEE: Double
    }

    /// Mirrors `NutritionComputer.computeCalorieBalance` — empirical TDEE path with lookback, rolling intake, ffill/bfill.
    static func computeCalorieBalance(
        intakeRows: [CalorieBalanceIntakeRow],
        tdeeRows: [CalorieBalanceTDEERow],
        scaleRows: [NutritionScaleAggregate],
        dateStart: Date,
        dateEnd: Date,
        minDate: Date,
        calendar: Calendar
    ) -> CalorieBalanceData? {
        let intakeByDate = Dictionary(intakeRows.map { ($0.date, $0.intakeKcal) }, uniquingKeysWith: { $1 })
        let tdeeByDate = Dictionary(tdeeRows.map { ($0.date, $0.appleTDEE) }, uniquingKeysWith: { $1 })

        let allDatesInRange = Set(intakeRows.map(\.date)).union(tdeeRows.map(\.date))
            .filter { $0 >= dateStart && $0 <= dateEnd }
            .sorted()

        guard !allDatesInRange.isEmpty else { return nil }

        let numberOfDays = calendar.dateComponents([.day], from: dateStart, to: dateEnd).day! + 1
        let lookbackWindow = min(max(numberOfDays, 14), 30)
        var lookbackStart = calendar.date(byAdding: .day, value: -lookbackWindow, to: dateStart)!
        if lookbackStart < minDate { lookbackStart = minDate }

        let intakeFull = intakeRows.filter { $0.date >= lookbackStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }
        let scaleFull = scaleRows.filter { $0.date >= lookbackStart && $0.date <= dateEnd }.sorted { $0.date < $1.date }

        let fullIntakeKcals = intakeFull.map(\.intakeKcal)
        let fullWeights: [Double?] = intakeFull.map { intake in
            nearestValue(in: scaleFull.compactMap { s in s.weightKg.map { (s.date, $0) } }, to: intake.date)
        }

        let empWindow = NutritionConstants.empiricalRollingWindowDays
        var deltaKgPerDay: [Double?] = Array(repeating: nil, count: intakeFull.count)
        for i in empWindow..<intakeFull.count {
            if let w1 = fullWeights[i], let w0 = fullWeights[i - empWindow] {
                deltaKgPerDay[i] = (w1 - w0) / Double(empWindow)
            }
        }

        let intake14dAvg = rollingMean(fullIntakeKcals, window: empWindow, minPeriods: empWindow / 2)

        var empiricalTDEE: [Double?] = Array(repeating: nil, count: intakeFull.count)
        for i in 0..<intakeFull.count {
            if let avg = intake14dAvg[i] {
                let delta = deltaKgPerDay[i] ?? 0
                empiricalTDEE[i] = avg - delta * NutritionConstants.kcalPerKgBodyWeight
            }
        }
        ffillBfill(&empiricalTDEE)

        var empTDEEByDate: [Date: Double] = [:]
        for (i, row) in intakeFull.enumerated() {
            if let v = empiricalTDEE[i] { empTDEEByDate[row.date] = v }
        }
        var empValuesForRange: [Double?] = allDatesInRange.map { empTDEEByDate[$0] }
        ffillBfill(&empValuesForRange)

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

    // MARK: - Weekly loss rates

    /// ISO Monday week buckets → weekly mean weight/BF → week-over-week deltas.
    static func computeWeeklyLossRates(
        scale: [NutritionScaleAggregate],
        dateStart: Date,
        dateEnd: Date
    ) -> WeeklyLossRateData? {
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
            let deltaWt: Double? = i > 0 ? ((weeklyMeans[i].meanWeight - weeklyMeans[i - 1].meanWeight) * 100).rounded() / 100 : nil
            var deltaBf: Double?
            if i > 0, let f1 = weeklyMeans[i].meanFat, let f0 = weeklyMeans[i - 1].meanFat {
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

    // MARK: - Rolling / helpers (shared with calorie balance & NutritionComputer)

    /// Centered rolling mean over optional values — ignores `nil` in each window.
    static func centeredRollingMeanOptional(_ values: [Double?], window: Int) -> [Double?] {
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

    /// Left-aligned rolling mean (pandas default without `center`).
    static func rollingMean(_ values: [Double], window: Int, minPeriods: Int) -> [Double?] {
        let n = values.count
        return (0..<n).map { i in
            let start = max(0, i - window + 1)
            let slice = Array(values[start...i])
            return slice.count >= minPeriods ? slice.reduce(0, +) / Double(slice.count) : nil
        }
    }

    static func ffillBfill(_ arr: inout [Double?]) {
        for i in 1..<arr.count {
            if arr[i] == nil { arr[i] = arr[i - 1] }
        }
        for i in stride(from: arr.count - 2, through: 0, by: -1) {
            if arr[i] == nil { arr[i] = arr[i + 1] }
        }
    }

    static func nearestValue(in entries: [(Date, Double)], to target: Date) -> Double? {
        guard !entries.isEmpty else { return nil }
        var best = entries[0]
        var bestDist = abs(target.timeIntervalSince(entries[0].0))
        for e in entries.dropFirst() {
            let dist = abs(target.timeIntervalSince(e.0))
            if dist < bestDist { best = e; bestDist = dist }
        }
        return best.1
    }

    private struct WeekGroup {
        let weekStart: Date
        var values: [(weight: Double, bf: Double?)]
    }

    /// ISO Monday-aligned week start (mirrors pandas `dt.to_period("W").dt.start_time`).
    static func mondayOfWeek(containing date: Date) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)!
    }

    private static func groupByMondayWeek(_ rows: [(date: Date, weight: Double, bf: Double?)]) -> [WeekGroup] {
        var groups: [Date: WeekGroup] = [:]
        for row in rows {
            let weekStart = mondayOfWeek(containing: row.date)
            var group = groups[weekStart] ?? WeekGroup(weekStart: weekStart, values: [])
            group.values.append((weight: row.weight, bf: row.bf))
            groups[weekStart] = group
        }
        return groups.values.sorted { $0.weekStart < $1.weekStart }
    }
}

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
