import XCTest
@testable import HealthCoach

final class CalorieBalanceAndWeeklyLossTests: XCTestCase {

    /// Matches `NutritionComputer`’s `Calendar` for date arithmetic in `computeCalorieBalance`.
    private let cal = Calendar(identifier: .iso8601)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Calorie balance (empirical TDEE path)

    /// Constant intake = Apple TDEE, flat weight → zero Apple & empirical balances; 7d rollings are zero.
    func testCalorieBalance_golden_constantIntakeFlatWeight_twoDayRange() {
        let minDate = day(2026, 1, 1)
        let dateStart = day(2026, 1, 20)
        let dateEnd = day(2026, 1, 21)
        // Lookback needs history from Jan 6 … Jan 21 (see lookbackWindow = 14).
        var intake: [NutritionKPIMath.CalorieBalanceIntakeRow] = []
        var tdee: [NutritionKPIMath.CalorieBalanceTDEERow] = []
        var scale: [NutritionScaleAggregate] = []
        for dom in 6...21 {
            let dt = day(2026, 1, dom)
            intake.append(NutritionKPIMath.CalorieBalanceIntakeRow(date: dt, intakeKcal: 2000))
            tdee.append(NutritionKPIMath.CalorieBalanceTDEERow(date: dt, appleTDEE: 2000))
            scale.append(NutritionScaleAggregate(date: dt, weightKg: 80, fatPercent: 20))
        }

        guard let data = NutritionKPIMath.computeCalorieBalance(
            intakeRows: intake,
            tdeeRows: tdee,
            scaleRows: scale,
            dateStart: dateStart,
            dateEnd: dateEnd,
            minDate: minDate,
            calendar: cal
        ) else {
            return XCTFail("expected CalorieBalanceData")
        }

        XCTAssertEqual(data.effectiveDays, 2)
        XCTAssertEqual(data.points.count, 2)
        XCTAssertEqual(data.points.map(\.date), [dateStart, dateEnd])

        for p in data.points {
            XCTAssertEqual(p.balanceApple!, 0, accuracy: 1e-9)
            XCTAssertEqual(p.balanceApple7d!, 0, accuracy: 1e-9)
            XCTAssertEqual(p.balanceEmpirical7d!, 0, accuracy: 1e-9)
        }
    }

    // MARK: - Weekly loss rates

    /// Two ISO weeks with falling mean weight and body fat → second bar shows negative deltas.
    func testWeeklyLossRates_golden_twoWeeks() {
        // 2026-01-05 is Monday (week 1). Week 2 starts 2026-01-12.
        let w1a = day(2026, 1, 6)
        let w1b = day(2026, 1, 10)
        let w2a = day(2026, 1, 13)
        let w2b = day(2026, 1, 17)

        let scale: [NutritionScaleAggregate] = [
            NutritionScaleAggregate(date: w1a, weightKg: 80, fatPercent: 20),
            NutritionScaleAggregate(date: w1b, weightKg: 80, fatPercent: 20),
            NutritionScaleAggregate(date: w2a, weightKg: 79, fatPercent: 19),
            NutritionScaleAggregate(date: w2b, weightKg: 79, fatPercent: 19),
        ]

        guard let data = NutritionKPIMath.computeWeeklyLossRates(
            scale: scale,
            dateStart: day(2026, 1, 1),
            dateEnd: day(2026, 1, 31)
        ) else {
            return XCTFail("expected WeeklyLossRateData")
        }

        XCTAssertEqual(data.points.count, 2)

        let w0 = NutritionKPIMath.mondayOfWeek(containing: w1a)
        let w1 = NutritionKPIMath.mondayOfWeek(containing: w2a)
        XCTAssertEqual(data.points[0].weekStart, w0)
        XCTAssertEqual(data.points[1].weekStart, w1)

        XCTAssertNil(data.points[0].deltaWeightKg)
        XCTAssertEqual(data.points[1].deltaWeightKg!, -1, accuracy: 1e-9)

        XCTAssertNil(data.points[0].deltaBodyFatPct)
        XCTAssertEqual(data.points[1].deltaBodyFatPct!, -1, accuracy: 1e-9)

        XCTAssertEqual(data.points[0].weekLabel, "Jan 05")
        XCTAssertEqual(data.points[1].weekLabel, "Jan 12")
    }
}
