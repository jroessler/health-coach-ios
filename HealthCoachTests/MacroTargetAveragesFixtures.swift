import Foundation
@testable import HealthCoach

/// Golden cases for Macro Overview (`MacroTargetData`): mean of **daily** macro % after filter + `computeMacroPct`.
enum MacroTargetAveragesFixtures {

    private static let cal: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private static func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day))!
    }

    struct Case {
        let id: String
        let dateStart: Date
        let dateEnd: Date
        let dailyMacros: [NutritionMacroAggregate]
        let expected: MacroTargetData
    }

    // MARK: - 30 / 40 / 30 split (2000 kcal): 150g P, 200g C, 66.67g F

    private static let grams30_40_30: (p: Double, c: Double, f: Double) = (150, 200, 66.67)

    /// (A) Single eligible day → averages equal that day’s rounded %.
    static let caseA_singleDay = Case(
        id: "macro_avg_a_single_day",
        dateStart: d(2026, 1, 15),
        dateEnd: d(2026, 1, 15),
        dailyMacros: [
            NutritionMacroAggregate(
                date: d(2026, 1, 15),
                calories: 2000,
                proteinG: grams30_40_30.p,
                carbsG: grams30_40_30.c,
                fatG: grams30_40_30.f
            ),
        ],
        expected: MacroTargetData(avgProteinPct: 30, avgCarbsPct: 40, avgFatPct: 30)
    )

    /// (B) Two identical days → same as one day.
    static let caseB_twoIdenticalDays = Case(
        id: "macro_avg_b_two_identical",
        dateStart: d(2026, 2, 1),
        dateEnd: d(2026, 2, 2),
        dailyMacros: [
            NutritionMacroAggregate(
                date: d(2026, 2, 1),
                calories: 2000,
                proteinG: grams30_40_30.p,
                carbsG: grams30_40_30.c,
                fatG: grams30_40_30.f
            ),
            NutritionMacroAggregate(
                date: d(2026, 2, 2),
                calories: 2000,
                proteinG: grams30_40_30.p,
                carbsG: grams30_40_30.c,
                fatG: grams30_40_30.f
            ),
        ],
        expected: MacroTargetData(avgProteinPct: 30, avgCarbsPct: 40, avgFatPct: 30)
    )

    /// (C) Two days with different daily % → unweighted mean of daily rounded %.
    static let caseC_twoDifferentDays = Case(
        id: "macro_avg_c_two_different",
        dateStart: d(2026, 3, 1),
        dateEnd: d(2026, 3, 2),
        dailyMacros: [
            NutritionMacroAggregate(
                date: d(2026, 3, 1),
                calories: 2000,
                proteinG: grams30_40_30.p,
                carbsG: grams30_40_30.c,
                fatG: grams30_40_30.f
            ),
            NutritionMacroAggregate(
                date: d(2026, 3, 2),
                calories: 2000,
                proteinG: 100,
                carbsG: 250,
                fatG: 88.89
            ),
        ],
        expected: MacroTargetData(avgProteinPct: 25, avgCarbsPct: 45, avgFatPct: 35)
    )

    /// (D) Day &lt; 500 kcal dropped by filter → only the full day counts (same as A for averages).
    static let caseD_lowCalorieDayExcluded = Case(
        id: "macro_avg_d_low_cal_excluded",
        dateStart: d(2026, 4, 1),
        dateEnd: d(2026, 4, 2),
        dailyMacros: [
            NutritionMacroAggregate(
                date: d(2026, 4, 1),
                calories: 2000,
                proteinG: grams30_40_30.p,
                carbsG: grams30_40_30.c,
                fatG: grams30_40_30.f
            ),
            NutritionMacroAggregate(
                date: d(2026, 4, 2),
                calories: 400,
                proteinG: 80,
                carbsG: 50,
                fatG: 10
            ),
        ],
        expected: MacroTargetData(avgProteinPct: 30, avgCarbsPct: 40, avgFatPct: 30)
    )

    /// (E) Daily protein % rounded to 1 dp before averaging (111.7g P → 22.3% at 2000 kcal).
    static let caseE_roundingBeforeMean = Case(
        id: "macro_avg_e_rounding",
        dateStart: d(2026, 5, 10),
        dateEnd: d(2026, 5, 10),
        dailyMacros: [
            NutritionMacroAggregate(
                date: d(2026, 5, 10),
                calories: 2000,
                proteinG: 111.7,
                carbsG: 200,
                fatG: 83.69
            ),
        ],
        expected: MacroTargetData(avgProteinPct: 22.3, avgCarbsPct: 40, avgFatPct: 37.7)
    )
}
