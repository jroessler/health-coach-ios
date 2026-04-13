import XCTest
@testable import HealthCoach

/// Goldens for `NutritionKPIMath.centeredRollingMean` and `prepareDailyCaloriesMacrosData`
/// (Daily Calories + Macros rolling line — consecutive filtered days, window 7 by default).
final class DailyCaloriesMacrosMathTests: XCTestCase {

    private let cal: Calendar = NutritionKPIFixtures.isoUTCCalendar

    private func utcDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - centeredRollingMean

    func testCenteredRollingMean_constantSevenDays_allEqualWindowMean() {
        let kcals = Array(repeating: 2000.0, count: 7)
        let rolling = NutritionKPIMath.centeredRollingMean(kcals, window: 7)
        XCTAssertEqual(rolling.count, 7)
        for v in rolling {
            XCTAssertNotNil(v)
            XCTAssertEqual(v!, 2000, accuracy: 1e-9)
        }
    }

    func testCenteredRollingMean_shortSeries_threePoints_allSameMean() {
        let kcals: [Double] = [1000, 2000, 3000]
        let rolling = NutritionKPIMath.centeredRollingMean(kcals, window: 7)
        XCTAssertEqual(rolling, [2000, 2000, 2000].map { Optional($0) })
    }

    func testCenteredRollingMean_fivePointRamp_goldenSeries() {
        let kcals: [Double] = [1000, 1500, 2000, 2500, 3000]
        let rolling = NutritionKPIMath.centeredRollingMean(kcals, window: 7)
        let expected: [Double] = [1750, 2000, 2000, 2000, 2250]
        XCTAssertEqual(rolling.count, expected.count)
        for i in 0..<expected.count {
            XCTAssertEqual(rolling[i]!, expected[i], accuracy: 1e-9, "index \(i)")
        }
    }

    func testCenteredRollingMean_sevenPointLinearRamp_goldenSeries() {
        let kcals = (0..<7).map { 1000.0 + Double($0) * 100 }
        let rolling = NutritionKPIMath.centeredRollingMean(kcals, window: 7)
        let expected: [Double] = [1150, 1200, 1250, 1300, 1350, 1400, 1450]
        XCTAssertEqual(rolling.count, expected.count)
        for i in 0..<expected.count {
            XCTAssertEqual(rolling[i]!, expected[i], accuracy: 1e-9, "index \(i)")
        }
    }

    func testCenteredRollingMean_emptyInput_returnsEmpty() {
        XCTAssertEqual(NutritionKPIMath.centeredRollingMean([], window: 7), [])
    }

    // MARK: - prepareDailyCaloriesMacrosData

    func testPrepareDailyCaloriesMacrosData_sortsByDateAndMatchesRolling() {
        let d1 = utcDay(2026, 2, 1)
        let d2 = utcDay(2026, 2, 2)
        let d3 = utcDay(2026, 2, 3)
        // Intentionally unsorted
        let rows = [
            NutritionMacroAggregate(date: d3, calories: 3000),
            NutritionMacroAggregate(date: d1, calories: 1000),
            NutritionMacroAggregate(date: d2, calories: 2000),
        ]
        let pct = NutritionKPIMath.computeMacroPct(rows)
        let data = NutritionKPIMath.prepareDailyCaloriesMacrosData(pct)

        XCTAssertEqual(data.effectiveDays, 3)
        XCTAssertEqual(data.points.count, 3)
        XCTAssertEqual(data.points.map(\.date), [d1, d2, d3])
        XCTAssertEqual(data.points.map(\.calories), [1000, 2000, 3000])

        let rolling = data.points.compactMap(\.rollingAvgKcal)
        XCTAssertEqual(rolling, [2000, 2000, 2000])
    }

    func testPrepareDailyCaloriesMacrosData_empty_returnsEmpty() {
        let data = NutritionKPIMath.prepareDailyCaloriesMacrosData([])
        XCTAssertTrue(data.points.isEmpty)
        XCTAssertEqual(data.effectiveDays, 0)
    }
}
