import Foundation
import SwiftData

// Mirrors health/app/services/heart.py — all formulas ported 1:1.
// Runs off the main thread via @ModelActor; returns pure Sendable structs.

@ModelActor
actor HeartComputer {

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

    // MARK: - Internal row types

    private struct DailyValue {
        let date: Date
        var value: Double
    }

    private struct DailyValueOpt {
        let date: Date
        var value: Double?
    }

    private struct HRVRow {
        let date: Date
        let hrv: Double
        let startDateStr: String?
    }

    private struct SetRow {
        let date: Date
        let weightKg: Double
        let reps: Double
    }

    private struct WorkoutRow {
        let date: Date
        let startTime: Date
    }

    // MARK: - Public entry point

    func compute(dateStart: Date, dateEnd: Date, userAge: Int) -> HeartSnapshot? {
        do {
            let store = HealthRecordStore.shared
            let hrvRaw = try store.loadHRVRecords()
            let rhrRaw = try store.loadRHRRecords()
            let vo2Raw = try store.loadVO2MaxRecords()
            let scaleRaw = try store.loadScale()

            guard !hrvRaw.isEmpty || !rhrRaw.isEmpty else { return nil }

            // Min date from earliest available HRV record
            let minDate: Date
            if let earliest = hrvRaw.min(by: { $0.date < $1.date })?.date {
                minDate = earliest
            } else if let earliest = rhrRaw.min(by: { $0.date < $1.date })?.date {
                minDate = earliest
            } else {
                minDate = dateStart
            }

            let periodLength = Self.cal.dateComponents([.day], from: dateStart, to: dateEnd).day ?? 0

            // Compute HRV
            let (hrvChart, baselineDaysHRV) = computeHRV(
                records: hrvRaw.map { HRVRow(date: $0.date, hrv: $0.hrvMs, startDateStr: $0.startDateStr) },
                minDate: minDate,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            // Compute RHR
            let (rhrChart, baselineDaysRHR) = computeRHR(
                records: rhrRaw.map { DailyValue(date: $0.date, value: $0.rhrBpm) },
                minDate: minDate,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            // Compute VO2
            let (vo2Chart, baselineDaysVO2) = computeVO2(
                records: vo2Raw.map { DailyValue(date: $0.date, value: $0.vo2Max) },
                minDate: minDate,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            // Compute VO2 vs Weight
            let vo2Weight = computeVO2Weight(
                vo2Points: vo2Chart.points,
                scale: scaleRaw,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            // Load workouts/sets from SwiftData
            let (sets, _) = loadWorkoutData()
            let volumeByDate = computeDailyVolume(sets)

            // Compute HRV vs Training Volume (needs full HRV daily from extended range)
            let hrvVolume = computeHRVVolume(
                hrvDaily: dailyAvgFromHRV(hrvRaw.map { HRVRow(date: $0.date, hrv: $0.hrvMs, startDateStr: $0.startDateStr) }),
                volumeByDate: volumeByDate,
                dateStart: dateStart,
                dateEnd: dateEnd,
                periodLength: periodLength
            )

            // Compute HRV vs Performance
            let hrvPerformance = computeHRVPerformance(
                hrvRecords: hrvRaw.map { HRVRow(date: $0.date, hrv: $0.hrvMs, startDateStr: $0.startDateStr) },
                volumeByDate: volumeByDate,
                dateStart: dateStart,
                dateEnd: dateEnd
            )

            // Compute KPIs
            let recoveryKPIs = HeartKPIMath.computeRecoveryKPIs(
                hrvPoints: hrvChart.points,
                rhrPoints: rhrChart.points
            )
            let (refs, ageLabel) = HeartConstants.vo2Refs(forAge: userAge)
            let fitnessKPIs = computeFitnessKPIs(
                vo2: vo2Chart,
                ageRefs: refs,
                ageLabel: ageLabel
            )

            let averagePeriod7d = min(7, periodLength)
            let averagePeriod14d = min(14, periodLength)

            return HeartSnapshot(
                recoveryKPIs: recoveryKPIs,
                fitnessKPIs: fitnessKPIs,
                hrv: HRVChartData(points: hrvChart.points, baselineDays: baselineDaysHRV, averagePeriod: averagePeriod7d),
                rhr: RHRChartData(points: rhrChart.points, baselineDays: baselineDaysRHR, averagePeriod: averagePeriod7d),
                vo2: VO2ChartData(points: vo2Chart.points, baselineDays: baselineDaysVO2, averagePeriod: averagePeriod14d),
                vo2Weight: vo2Weight,
                hrvVolume: hrvVolume,
                hrvPerformance: hrvPerformance,
                periodLength: periodLength,
                baselineDaysHRV: baselineDaysHRV,
                baselineDaysRHR: baselineDaysRHR,
                baselineDaysVO2: baselineDaysVO2
            )
        } catch {
            return nil
        }
    }

    // MARK: - compute_hrv (mirrors heart.py compute_hrv exactly)

    private struct HRVComputeResult {
        let points: [HRVDayPoint]
    }

    private func computeHRV(
        records: [HRVRow],
        minDate: Date,
        dateStart: Date,
        dateEnd: Date,
        baselineDays: Int = 30
    ) -> (HRVComputeResult, Int) {
        let minDateNorm = Self.startOfDay(minDate)
        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        let periodDays = Self.cal.dateComponents([.day], from: dateStartNorm, to: dateEndNorm).day ?? 0

        let baselineStartNorm: Date
        let baselineDaysActual: Int
        if periodDays <= 30 {
            let candidate = Self.cal.date(byAdding: .day, value: -baselineDays, to: dateEndNorm)!
            baselineStartNorm = max(minDateNorm, candidate)
            baselineDaysActual = Self.cal.dateComponents([.day], from: baselineStartNorm, to: dateEndNorm).day ?? baselineDays
        } else {
            baselineStartNorm = dateStartNorm
            baselineDaysActual = 30
        }

        // Extended range for baseline computation
        let extended = records.filter { $0.date >= baselineStartNorm && $0.date <= dateEndNorm }
        // Display range only
        let filtered = records.filter { $0.date >= dateStartNorm && $0.date <= dateEndNorm }

        // Daily average of hrv_ms for display range
        var dailyByDate: [Date: [Double]] = [:]
        for r in filtered {
            dailyByDate[r.date, default: []].append(r.hrv)
        }
        let dailyPoints = dailyByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        // hrv_7d = rolling(7, min_periods=1).mean on display range
        let hrv7d = HeartKPIMath.leftRollingMean(dailyPoints.map(\.value), window: 7, minPeriods: 1)

        // Baseline: daily avg across extended range
        var baselineByDate: [Date: [Double]] = [:]
        for r in extended {
            baselineByDate[r.date, default: []].append(r.hrv)
        }
        let baselineDailyPoints = baselineByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        let baselineVals = baselineDailyPoints.map(\.value)
        // rolling(30, min_periods=7).mean and .std on baseline points
        let baselineMeans = HeartKPIMath.leftRollingMean(baselineVals, window: 30, minPeriods: 7)
        let baselineSDs = HeartKPIMath.leftRollingStd(baselineVals, window: 30, minPeriods: 7, fillZero: true)

        // Build lookup by date from baseline
        var baselineLookup: [Date: (mean: Double?, sd: Double)] = [:]
        for (i, bp) in baselineDailyPoints.enumerated() {
            baselineLookup[bp.date] = (baselineMeans[i], baselineSDs[i] ?? 0)
        }

        // Merge baseline into daily display points
        let points: [HRVDayPoint] = dailyPoints.enumerated().map { (i, dp) in
            let baselineEntry = baselineLookup[dp.date]
            let baseline = baselineEntry?.mean
            let sd = baselineEntry?.sd ?? 0
            let upper = baseline.map { $0 + sd }
            let lower = baseline.map { $0 - sd }
            let lower2 = baseline.map { $0 - 2 * sd }
            let pctDev: Double? = baseline.flatMap { b in
                b > 0 ? HeartKPIMath.rounded((dp.value - b) / b * 100, decimals: 1) : 0
            }
            return HRVDayPoint(
                date: dp.date,
                hrv: dp.value,
                hrv7d: hrv7d[i],
                baseline: baseline,
                sd: sd,
                upper: upper,
                lower: lower,
                lower2: lower2,
                pctDev: pctDev
            )
        }

        return (HRVComputeResult(points: points), baselineDaysActual)
    }

    // MARK: - compute_rhr (mirrors heart.py compute_rhr exactly)

    private struct RHRComputeResult {
        let points: [RHRDayPoint]
    }

    private func computeRHR(
        records: [DailyValue],
        minDate: Date,
        dateStart: Date,
        dateEnd: Date,
        baselineDays: Int = 30
    ) -> (RHRComputeResult, Int) {
        let minDateNorm = Self.startOfDay(minDate)
        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        let periodDays = Self.cal.dateComponents([.day], from: dateStartNorm, to: dateEndNorm).day ?? 0

        let baselineStartNorm: Date
        let baselineDaysActual: Int
        if periodDays <= 30 {
            let candidate = Self.cal.date(byAdding: .day, value: -baselineDays, to: dateEndNorm)!
            baselineStartNorm = max(minDateNorm, candidate)
            baselineDaysActual = Self.cal.dateComponents([.day], from: baselineStartNorm, to: dateEndNorm).day ?? baselineDays
        } else {
            baselineStartNorm = dateStartNorm
            baselineDaysActual = 30
        }

        let extended = records.filter { $0.date >= baselineStartNorm && $0.date <= dateEndNorm }
        let filtered = records.filter { $0.date >= dateStartNorm && $0.date <= dateEndNorm }

        // Daily average of rhr_bpm for display range
        var dailyByDate: [Date: [Double]] = [:]
        for r in filtered { dailyByDate[r.date, default: []].append(r.value) }
        let dailyPoints = dailyByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        let rhr7d = HeartKPIMath.leftRollingMean(dailyPoints.map(\.value), window: 7, minPeriods: 1)

        // Baseline
        var baselineByDate: [Date: [Double]] = [:]
        for r in extended { baselineByDate[r.date, default: []].append(r.value) }
        let baselineDailyPoints = baselineByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        let baselineVals = baselineDailyPoints.map(\.value)
        let baselineMeans = HeartKPIMath.leftRollingMean(baselineVals, window: 30, minPeriods: 7)
        let baselineSDs = HeartKPIMath.leftRollingStd(baselineVals, window: 30, minPeriods: 7, fillZero: true)

        var baselineLookup: [Date: (mean: Double?, sd: Double)] = [:]
        for (i, bp) in baselineDailyPoints.enumerated() {
            baselineLookup[bp.date] = (baselineMeans[i], baselineSDs[i] ?? 0)
        }

        let points: [RHRDayPoint] = dailyPoints.enumerated().map { (i, dp) in
            let baselineEntry = baselineLookup[dp.date]
            let baseline = baselineEntry?.mean
            let sd = baselineEntry?.sd ?? 0
            let upper = baseline.map { $0 + sd }
            let upper2 = baseline.map { $0 + 2 * sd }
            let lower = baseline.map { $0 - sd }
            return RHRDayPoint(
                date: dp.date,
                rhr: dp.value,
                rhr7d: rhr7d[i],
                baseline: baseline,
                sd: sd,
                upper: upper,
                upper2: upper2,
                lower: lower
            )
        }

        return (RHRComputeResult(points: points), baselineDaysActual)
    }

    // MARK: - compute_vo2 (mirrors heart.py compute_vo2 exactly)

    private struct VO2ComputeResult {
        let points: [VO2DayPoint]
    }

    private func computeVO2(
        records: [DailyValue],
        minDate: Date,
        dateStart: Date,
        dateEnd: Date,
        baselineDays: Int = 30
    ) -> (VO2ComputeResult, Int) {
        let minDateNorm = Self.startOfDay(minDate)
        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        let periodDays = Self.cal.dateComponents([.day], from: dateStartNorm, to: dateEndNorm).day ?? 0

        let baselineStartNorm: Date
        let baselineDaysActual: Int
        if periodDays <= 30 {
            let candidate = Self.cal.date(byAdding: .day, value: -baselineDays, to: dateEndNorm)!
            baselineStartNorm = max(minDateNorm, candidate)
            baselineDaysActual = Self.cal.dateComponents([.day], from: baselineStartNorm, to: dateEndNorm).day ?? baselineDays
        } else {
            baselineStartNorm = dateStartNorm
            baselineDaysActual = 30
        }

        let extended = records.filter { $0.date >= baselineStartNorm && $0.date <= dateEndNorm }
        let filtered = records.filter { $0.date >= dateStartNorm && $0.date <= dateEndNorm }

        // Daily avg for display range
        var dailyByDate: [Date: [Double]] = [:]
        for r in filtered { dailyByDate[r.date, default: []].append(r.value) }
        let dailyPoints = dailyByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        // vo2_14d = rolling(14, min_periods=1).mean
        let vo214d = HeartKPIMath.leftRollingMean(dailyPoints.map(\.value), window: 14, minPeriods: 1)

        // Baseline (extended range): rolling(30, min_periods=1).mean
        var baselineByDate: [Date: [Double]] = [:]
        for r in extended { baselineByDate[r.date, default: []].append(r.value) }
        let baselineDailyPoints = baselineByDate.map { (date, values) in
            DailyValue(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }

        let baselineMeans = HeartKPIMath.leftRollingMean(baselineDailyPoints.map(\.value), window: 30, minPeriods: 1)

        var baselineLookup: [Date: Double?] = [:]
        for (i, bp) in baselineDailyPoints.enumerated() {
            baselineLookup[bp.date] = baselineMeans[i]
        }

        let points: [VO2DayPoint] = dailyPoints.enumerated().map { (i, dp) in
            VO2DayPoint(
                date: dp.date,
                vo2Max: dp.value,
                vo214d: vo214d[i],
                baseline: baselineLookup[dp.date] ?? nil
            )
        }

        return (VO2ComputeResult(points: points), baselineDaysActual)
    }

    // MARK: - compute_vo2_weight (mirrors heart.py compute_vo2_weight exactly)

    private func computeVO2Weight(
        vo2Points: [VO2DayPoint],
        scale: [HealthRecordStore.ScaleRow],
        dateStart: Date,
        dateEnd: Date
    ) -> VO2WeightData? {
        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        let vo2InRange = vo2Points.filter { $0.date >= dateStartNorm && $0.date <= dateEndNorm }
        guard !vo2InRange.isEmpty else { return nil }

        // Weight daily avg + 7d rolling
        let weightFiltered = scale.filter {
            $0.date >= dateStartNorm && $0.date <= dateEndNorm
        }.compactMap { row -> DailyValue? in
            guard let w = row.weightKg else { return nil }
            return DailyValue(date: row.date, value: w)
        }.sorted { $0.date < $1.date }

        let weight7d = HeartKPIMath.leftRollingMean(weightFiltered.map(\.value), window: 7, minPeriods: 1)

        // Build weight lookup (date → 7d rolling avg)
        var weightLookup: [Date: (raw: Double, rolling: Double?)] = [:]
        for (i, w) in weightFiltered.enumerated() {
            weightLookup[w.date] = (w.value, weight7d[i])
        }

        // Merge VO2 + weight across outer (all dates in either set)
        let allDates = Set(vo2Points.map(\.date)).union(weightFiltered.map(\.date))
        let sortedDates = allDates.sorted()

        // Build preliminary VO2 lookup
        var vo2Lookup: [Date: (max: Double, baseline: Double?)] = [:]
        for p in vo2Points { vo2Lookup[p.date] = (p.vo2Max, p.baseline) }

        // Ffill weight_7d and vo2_baseline across all dates
        var weight7dSeries: [Double?] = sortedDates.map { weightLookup[$0]?.rolling }
        var vo2BaselineSeries: [Double?] = sortedDates.map { vo2Lookup[$0]?.baseline }
        HeartKPIMath.forwardFill(&weight7dSeries)
        HeartKPIMath.forwardFill(&vo2BaselineSeries)

        let vo2AbsSeries: [Double?] = sortedDates.enumerated().map { (i, date) in
            guard let vo2 = vo2Lookup[date]?.max, let wt = weight7dSeries[i] else { return nil }
            return vo2 * wt
        }

        // vo2_absolute_14d = rolling(14, min_periods=1).mean on absolute series
        let vo2Abs14dRaw = HeartKPIMath.leftRollingMeanOptional(vo2AbsSeries, window: 14, minPeriods: 1)

        let points: [VO2WeightPoint] = sortedDates.enumerated().map { (i, date) in
            VO2WeightPoint(
                date: date,
                weightKg: weightLookup[date]?.raw,
                weight7d: weightLookup[date]?.rolling,
                weightFfill: weight7dSeries[i],
                vo2Max: vo2Lookup[date]?.max,
                vo2Baseline: vo2BaselineSeries[i],
                vo2Absolute: vo2AbsSeries[i],
                vo2Absolute14d: vo2Abs14dRaw[i]
            )
        }

        return VO2WeightData(points: points)
    }

    // MARK: - compute_heart_kpis (mirrors heart.py compute_heart_kpis exactly)

    private func computeFitnessKPIs(
        vo2: VO2ComputeResult,
        ageRefs: VO2Refs,
        ageLabel: String
    ) -> FitnessKPIs {
        let vo2AgeRefs = VO2AgeRefs(
            ageLabel: ageLabel,
            below: ageRefs.below,
            average: ageRefs.average,
            elite: ageRefs.elite
        )

        guard !vo2.points.isEmpty else {
            return FitnessKPIs(vo2Current: nil, vo2Delta30d: nil, vo2AgeRefs: vo2AgeRefs)
        }

        let vo2Current = vo2.points.last?.vo2Max

        // vo2_delta_30d = vo2_baseline.last - vo2_14d.last  (mirrors 3_Heart.py lines 481-482)
        let vo2Delta30d = HeartKPIMath.vo2Delta30d(
            lastBaseline: vo2.points.last?.baseline,
            last14d: vo2.points.last?.vo214d
        )

        return FitnessKPIs(vo2Current: vo2Current, vo2Delta30d: vo2Delta30d, vo2AgeRefs: vo2AgeRefs)
    }

    // MARK: - load_hrv_volume_data (mirrors heart.py load_hrv_volume_data)

    private func computeHRVVolume(
        hrvDaily: [Date: Double],
        volumeByDate: [Date: Double],
        dateStart: Date,
        dateEnd: Date,
        periodLength: Int
    ) -> HRVVolumeData? {
        guard !hrvDaily.isEmpty else { return nil }

        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        // Reindex HRV to fill missing days within range
        var minHRVDate = hrvDaily.keys.min() ?? dateStartNorm
        var maxHRVDate = hrvDaily.keys.max() ?? dateEndNorm
        minHRVDate = max(minHRVDate, dateStartNorm)
        maxHRVDate = min(maxHRVDate, dateEndNorm)

        var allDates: [Date] = []
        var current = minHRVDate
        while current <= maxHRVDate {
            allDates.append(current)
            current = Self.cal.date(byAdding: .day, value: 1, to: current)!
        }

        // Lag volume by +1 and +2 days (volume on day X → appears on X+1 and X+2)
        // lagged_volume = max(vol_lag1, vol_lag2)
        let avgPeriod = min(7, periodLength)
        let hrvValues: [Double?] = allDates.map { hrvDaily[$0] }
        let hrv7d = HeartKPIMath.leftRollingMeanOptional(hrvValues, window: 7, minPeriods: 1)

        let points: [HRVVolumePoint] = allDates.enumerated().compactMap { (i, date) in
            let lag1Date = Self.cal.date(byAdding: .day, value: -1, to: date)!
            let lag2Date = Self.cal.date(byAdding: .day, value: -2, to: date)!
            let volLag1 = volumeByDate[lag1Date]
            let volLag2 = volumeByDate[lag2Date]
            let laggedVolume = HeartKPIMath.laggedTrainingVolume(volLag1: volLag1, volLag2: volLag2)

            guard hrvValues[i] != nil || laggedVolume != nil else { return nil }

            return HRVVolumePoint(
                date: date,
                hrv: hrvValues[i],
                hrv7d: hrv7d[i],
                laggedVolume: laggedVolume
            )
        }

        return HRVVolumeData(points: points, averagePeriod: avgPeriod)
    }

    // MARK: - load_hrv_performance_data (mirrors heart.py load_hrv_performance_data)

    private func computeHRVPerformance(
        hrvRecords: [HRVRow],
        volumeByDate: [Date: Double],
        dateStart: Date,
        dateEnd: Date
    ) -> HRVPerformanceData? {
        // hrv_morning: earliest reading per day (sort by start_date, take first)
        // Same as Python: hrv_raw.sort_values("start_date").groupby("Date").first()
        var morningByDate: [Date: (hrv: Double, startDateStr: String)] = [:]
        for r in hrvRecords.sorted(by: { ($0.startDateStr ?? "") < ($1.startDateStr ?? "") }) {
            if morningByDate[r.date] == nil {
                morningByDate[r.date] = (r.hrv, r.startDateStr ?? "")
            }
        }

        // Inner join with workout volume (volume > 0 only)
        var combined: [(date: Date, hrv: Double, volume: Double)] = []
        for (date, entry) in morningByDate {
            guard let vol = volumeByDate[date], vol > 0 else { continue }
            combined.append((date: date, hrv: entry.hrv, volume: vol))
        }

        guard combined.count >= 5 else { return nil }
        combined.sort { $0.date < $1.date }

        // Filter to date range for the chart (but use all data for p33/p66 — matches Python)
        let dateStartNorm = Self.startOfDay(dateStart)
        let dateEndNorm = Self.startOfDay(dateEnd)

        let hrvValues = combined.map(\.hrv)
        let p33 = HeartKPIMath.percentile(hrvValues, p: 0.33)
        let p66 = HeartKPIMath.percentile(hrvValues, p: 0.66)

        // Zone assignment
        let inRange = combined.filter { $0.date >= dateStartNorm && $0.date <= dateEndNorm }
        guard inRange.count >= 5 else { return nil }

        let points: [HRVPerformancePoint] = inRange.map { item in
            let zone: HRVZone
            if item.hrv < p33 { zone = .low }
            else if item.hrv < p66 { zone = .moderate }
            else { zone = .high }
            return HRVPerformancePoint(date: item.date, hrv: item.hrv, volume: item.volume, zone: zone)
        }

        // Zone averages
        let lowAvg = HeartKPIMath.mean(points.filter { $0.zone == .low }.map(\.volume))
        let modAvg = HeartKPIMath.mean(points.filter { $0.zone == .moderate }.map(\.volume))
        let highAvg = HeartKPIMath.mean(points.filter { $0.zone == .high }.map(\.volume))

        // Linear regression (least squares)
        let (slope, intercept) = HeartKPIMath.linearRegression(
            x: points.map(\.hrv),
            y: points.map(\.volume)
        )

        return HRVPerformanceData(
            points: points,
            p33: p33,
            p66: p66,
            zoneAverages: ZoneAverages(low: lowAvg, moderate: modAvg, high: highAvg),
            regressionSlope: slope,
            regressionIntercept: intercept
        )
    }

    // MARK: - Data loading helpers

    private func loadWorkoutData() -> ([SetRow], [WorkoutRow]) {
        do {
            let ctx = ModelContext(modelContainer)
            let sets = try ctx.fetch(FetchDescriptor<WorkoutSet>())
            let setRows: [SetRow] = sets.compactMap { s in
                guard let d = Self.dateFmt.date(from: s.date) else { return nil }
                return SetRow(date: d, weightKg: s.weightKg ?? 0, reps: Double(s.reps ?? 0))
            }
            let workouts = try ctx.fetch(FetchDescriptor<Workout>())
            let workoutRows: [WorkoutRow] = workouts.compactMap { w in
                guard let d = Self.dateFmt.date(from: w.date) else { return nil }
                let st = Self.parseDateTime(w.startTime) ?? d
                return WorkoutRow(date: d, startTime: st)
            }
            return (setRows, workoutRows)
        } catch {
            return ([], [])
        }
    }

    private func computeDailyVolume(_ sets: [SetRow]) -> [Date: Double] {
        var byDate: [Date: Double] = [:]
        for s in sets {
            byDate[s.date, default: 0] += s.weightKg * s.reps
        }
        return byDate
    }

    private func dailyAvgFromHRV(_ records: [HRVRow]) -> [Date: Double] {
        var byDate: [Date: [Double]] = [:]
        for r in records { byDate[r.date, default: []].append(r.hrv) }
        return byDate.mapValues { HeartKPIMath.mean($0) }
    }

    private static func parseDateTime(_ s: String) -> Date? {
        isoFmt.date(from: s) ?? isoFmtNoFrac.date(from: s)
    }

    private static func startOfDay(_ date: Date) -> Date {
        cal.startOfDay(for: date)
    }
}
