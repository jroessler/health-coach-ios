import Foundation
@testable import HealthCoach

/// Golden toy data for nutrition KPI unit tests. Dates use ISO-8601 calendar + UTC so windows are stable in CI.
enum NutritionKPIFixtures {

    /// Same calendar semantics as tests; not necessarily identical to device `Calendar.current` in the app UI.
    static let isoUTCCalendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    struct GoldenCase {
        let id: String
        let dateStart: Date
        let dateEnd: Date
        /// Raw daily totals (aggregated-by-day shape, same as NutritionComputer after loadMacros).
        let dailyMacros: [NutritionMacroAggregate]
        let scale: [NutritionScaleAggregate]
        /// Expected KPI row — confirm before treating as locked gold.
        let expected: NutritionKPIs
    }

    private static func utcDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        isoUTCCalendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Last-7 average kcal: 14-day range 2026-01-01 … 2026-01-14; last 7 days 2026-01-08 … 2026-01-14.
    /// Kcal series matches the toy spreadsheet (1500×7, then 1800…2000). Sum of last 7 = 13800 → mean 13800/7.
    static let last7dAvgKcal_caseA = GoldenCase(
        id: "last7d_avg_kcal_case_a",
        dateStart: utcDay(2026, 1, 1),
        dateEnd: utcDay(2026, 1, 14),
        dailyMacros: {
            let kcals = [1500, 1500, 1500, 1500, 1500, 1500, 1500, 1800, 1900, 2000, 2100, 2000, 2000, 2000]
            return (0..<14).map { i in
                NutritionMacroAggregate(date: utcDay(2026, 1, i + 1), calories: Double(kcals[i]))
            }
        }(),
        scale: [],
        expected: NutritionKPIs(
            last7dAvgKcal: 13800.0 / 7.0,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: nil
        )
    )

    /// Range shorter than 7 days: mean is over all eligible days in the last-7 window (here, 3 days).
    static let last7dAvgKcal_caseB = GoldenCase(
        id: "last7d_avg_kcal_case_b",
        dateStart: utcDay(2026, 3, 1),
        dateEnd: utcDay(2026, 3, 3),
        dailyMacros: [
            NutritionMacroAggregate(date: utcDay(2026, 3, 1), calories: 1200),
            NutritionMacroAggregate(date: utcDay(2026, 3, 2), calories: 1500),
            NutritionMacroAggregate(date: utcDay(2026, 3, 3), calories: 1800),
        ],
        scale: [],
        expected: NutritionKPIs(
            last7dAvgKcal: 1500,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: nil
        )
    )

    /// One day in the last-7 window below 500 kcal: excluded from macros → mean over 6 days, not 7.
    static let last7dAvgKcal_caseC = GoldenCase(
        id: "last7d_avg_kcal_case_c",
        dateStart: utcDay(2026, 1, 1),
        dateEnd: utcDay(2026, 1, 14),
        dailyMacros: {
            let kcals = [1500, 1500, 1500, 1500, 1500, 1500, 1500, 1800, 1900, 400, 2100, 2000, 2000, 2000]
            return (0..<14).map { i in
                NutritionMacroAggregate(date: utcDay(2026, 1, i + 1), calories: Double(kcals[i]))
            }
        }(),
        scale: [],
        expected: NutritionKPIs(
            last7dAvgKcal: 11800.0 / 6.0,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: nil
        )
    )

    // MARK: - Scale deltas (total weight / total body fat change)

    /// Two weigh-ins, no body fat % → weight delta only.
    static let scale_twoPoints_weightOnly = GoldenCase(
        id: "scale_two_points_weight_only",
        dateStart: utcDay(2026, 5, 1),
        dateEnd: utcDay(2026, 5, 14),
        dailyMacros: (0..<14).map { i in
            NutritionMacroAggregate(date: utcDay(2026, 5, i + 1), calories: 2000)
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 5, 1), weightKg: 80, fatPercent: nil),
            NutritionScaleAggregate(date: utcDay(2026, 5, 14), weightKg: 78, fatPercent: nil),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: -2,
            sevenDayProteinPerKg: 0
        )
    )

    /// Two weigh-ins with body fat → both deltas (same calendar endpoints).
    static let scale_twoPoints_weightAndBodyFat = GoldenCase(
        id: "scale_two_points_weight_and_body_fat",
        dateStart: utcDay(2026, 5, 1),
        dateEnd: utcDay(2026, 5, 14),
        dailyMacros: (0..<14).map { i in
            NutritionMacroAggregate(date: utcDay(2026, 5, i + 1), calories: 2000)
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 5, 1), weightKg: 80, fatPercent: 22),
            NutritionScaleAggregate(date: utcDay(2026, 5, 14), weightKg: 78, fatPercent: 20),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: -2,
            totalWeightChange: -2,
            sevenDayProteinPerKg: 0
        )
    )

    /// Three weigh-ins; BF missing on first day → weight uses day1 vs day3; BF uses day2 vs day3 only.
    static let scale_threePoints_bodyFatMissingFirstDay = GoldenCase(
        id: "scale_three_points_bf_missing_first_day",
        dateStart: utcDay(2026, 6, 1),
        dateEnd: utcDay(2026, 6, 3),
        dailyMacros: (0..<3).map { i in
            NutritionMacroAggregate(date: utcDay(2026, 6, i + 1), calories: 2000)
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 6, 1), weightKg: 80, fatPercent: nil),
            NutritionScaleAggregate(date: utcDay(2026, 6, 2), weightKg: 79, fatPercent: 20),
            NutritionScaleAggregate(date: utcDay(2026, 6, 3), weightKg: 78, fatPercent: 19),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: -1,
            totalWeightChange: -2,
            sevenDayProteinPerKg: 0
        )
    )

    // MARK: - 7d avg protein / kg (sevenDayProteinPerKg)

    /// (1) No scale in range and none before → protein/kg is nil (no default weight).
    static let protein_case1_noWeightAnywhere = GoldenCase(
        id: "protein_case1_no_weight_anywhere",
        dateStart: utcDay(2026, 7, 1),
        dateEnd: utcDay(2026, 7, 14),
        dailyMacros: (0..<14).map { i in
            let day = i + 1
            let inLast7 = day >= 8
            return NutritionMacroAggregate(
                date: utcDay(2026, 7, day),
                calories: 2000,
                proteinG: inLast7 ? 100 : 0
            )
        },
        scale: [],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: nil
        )
    )

    /// (2) Weight in range — latest in-range weigh-in (80 kg) for divisor; single point so no weight *change* KPI.
    static let protein_case2_weightInRange = GoldenCase(
        id: "protein_case2_weight_in_range",
        dateStart: utcDay(2026, 8, 1),
        dateEnd: utcDay(2026, 8, 14),
        dailyMacros: (0..<14).map { i in
            let day = i + 1
            let inLast7 = day >= 8
            return NutritionMacroAggregate(
                date: utcDay(2026, 8, day),
                calories: 2000,
                proteinG: inLast7 ? 100 : 0
            )
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 8, 14), weightKg: 80, fatPercent: nil),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: 1.25
        )
    )

    /// (3) Single mid-range weigh-in — latest weight in range is that day (not end of calendar range).
    static let protein_case3_singleWeighInMidRange = GoldenCase(
        id: "protein_case3_single_weigh_in_mid_range",
        dateStart: utcDay(2026, 9, 1),
        dateEnd: utcDay(2026, 9, 14),
        dailyMacros: (0..<14).map { i in
            let day = i + 1
            let inLast7 = day >= 8
            return NutritionMacroAggregate(
                date: utcDay(2026, 9, day),
                calories: 2000,
                proteinG: inLast7 ? 80 : 0
            )
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 9, 10), weightKg: 80, fatPercent: nil),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: 1
        )
    )

    /// (4) Low-calorie day excluded from macros → protein mean over 6 days; weight from in-range scale.
    static let protein_case4_lowCalorieDayExcludesProteinFromMean = GoldenCase(
        id: "protein_case4_low_calorie_excludes",
        dateStart: utcDay(2026, 1, 1),
        dateEnd: utcDay(2026, 1, 14),
        dailyMacros: {
            var rows: [NutritionMacroAggregate] = []
            for i in 0..<14 {
                let day = i + 1
                let kcal: Double
                let prot: Double
                switch day {
                case 1...7:
                    kcal = 1500
                    prot = 0
                case 8, 9:
                    kcal = 2000
                    prot = 100
                case 10:
                    kcal = 400
                    prot = 100
                default:
                    kcal = 2000
                    prot = 100
                }
                rows.append(NutritionMacroAggregate(date: utcDay(2026, 1, day), calories: kcal, proteinG: prot))
            }
            return rows
        }(),
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 1, 14), weightKg: 75, fatPercent: nil),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: 1.33
        )
    )

    /// (5) Short range, no weight in range — fall back to most recent scale before `dateStart`.
    static let protein_case5_preRangeWeightFallback = GoldenCase(
        id: "protein_case5_pre_range_weight_fallback",
        dateStart: utcDay(2026, 4, 1),
        dateEnd: utcDay(2026, 4, 3),
        dailyMacros: (0..<3).map { i in
            NutritionMacroAggregate(date: utcDay(2026, 4, i + 1), calories: 2000, proteinG: 120)
        },
        scale: [
            NutritionScaleAggregate(date: utcDay(2026, 3, 31), weightKg: 75, fatPercent: nil),
        ],
        expected: NutritionKPIs(
            last7dAvgKcal: 2000,
            totalBodyFatChange: nil,
            totalWeightChange: nil,
            sevenDayProteinPerKg: 1.6
        )
    )
}
