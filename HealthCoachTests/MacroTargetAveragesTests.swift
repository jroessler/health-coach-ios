import XCTest
@testable import HealthCoach

final class MacroTargetAveragesTests: XCTestCase {

    func testMacroTarget_caseA_singleDay() {
        assertMacroOverview(MacroTargetAveragesFixtures.caseA_singleDay)
    }

    func testMacroTarget_caseB_twoIdenticalDays() {
        assertMacroOverview(MacroTargetAveragesFixtures.caseB_twoIdenticalDays)
    }

    func testMacroTarget_caseC_twoDifferentDays() {
        assertMacroOverview(MacroTargetAveragesFixtures.caseC_twoDifferentDays)
    }

    func testMacroTarget_caseD_lowCalorieExcluded() {
        assertMacroOverview(MacroTargetAveragesFixtures.caseD_lowCalorieDayExcluded)
    }

    func testMacroTarget_caseE_roundingBeforeMean() {
        assertMacroOverview(MacroTargetAveragesFixtures.caseE_roundingBeforeMean)
    }

    func testMacroTarget_emptyAfterFilter() {
        let cal = NutritionKPIFixtures.isoUTCCalendar
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let end = cal.date(from: DateComponents(year: 2026, month: 6, day: 7))!
        let onlyLowCal = [
            NutritionMacroAggregate(date: start, calories: 400, proteinG: 50, carbsG: 50, fatG: 10),
        ]
        let filtered = NutritionKPIMath.filterMacros(onlyLowCal, dateStart: start, dateEnd: end)
        let pct = NutritionKPIMath.computeMacroPct(filtered)
        let result = NutritionKPIMath.computeMacroPctAverages(pct)
        XCTAssertNil(result.avgProteinPct)
        XCTAssertNil(result.avgCarbsPct)
        XCTAssertNil(result.avgFatPct)
    }

    private func assertMacroOverview(_ c: MacroTargetAveragesFixtures.Case, file: StaticString = #filePath, line: UInt = #line) {
        let filtered = NutritionKPIMath.filterMacros(c.dailyMacros, dateStart: c.dateStart, dateEnd: c.dateEnd)
        let pct = NutritionKPIMath.computeMacroPct(filtered)
        let actual = NutritionKPIMath.computeMacroPctAverages(pct)
        assertMacroTargetDataEqual(actual, c.expected, file: file, line: line)
    }

    private func assertMacroTargetDataEqual(
        _ actual: MacroTargetData,
        _ expected: MacroTargetData,
        accuracy: Double = 1e-9,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertOptionalPctEqual(actual.avgProteinPct, expected.avgProteinPct, accuracy: accuracy, file: file, line: line)
        assertOptionalPctEqual(actual.avgCarbsPct, expected.avgCarbsPct, accuracy: accuracy, file: file, line: line)
        assertOptionalPctEqual(actual.avgFatPct, expected.avgFatPct, accuracy: accuracy, file: file, line: line)
    }

    private func assertOptionalPctEqual(
        _ actual: Double?,
        _ expected: Double?,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (actual, expected) {
        case (nil, nil):
            return
        case let (a?, e?):
            XCTAssertEqual(a, e, accuracy: accuracy, file: file, line: line)
        default:
            XCTFail("Expected \(String(describing: expected)), got \(String(describing: actual))", file: file, line: line)
        }
    }
}
