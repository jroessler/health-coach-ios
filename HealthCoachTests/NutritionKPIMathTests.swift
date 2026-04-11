import XCTest
@testable import HealthCoach

final class NutritionKPIMathTests: XCTestCase {

    func testLast7dAvgKcal_caseA() {
        assertGoldenKPIs(NutritionKPIFixtures.last7dAvgKcal_caseA)
    }

    func testLast7dAvgKcal_caseB_shortRange() {
        assertGoldenKPIs(NutritionKPIFixtures.last7dAvgKcal_caseB)
    }

    func testLast7dAvgKcal_caseC_lowCalorieDayExcluded() {
        assertGoldenKPIs(NutritionKPIFixtures.last7dAvgKcal_caseC)
    }

    func testScale_twoPoints_weightOnly() {
        assertGoldenKPIs(NutritionKPIFixtures.scale_twoPoints_weightOnly)
    }

    func testScale_twoPoints_weightAndBodyFat() {
        assertGoldenKPIs(NutritionKPIFixtures.scale_twoPoints_weightAndBodyFat)
    }

    func testScale_threePoints_bodyFatMissingFirstDay() {
        assertGoldenKPIs(NutritionKPIFixtures.scale_threePoints_bodyFatMissingFirstDay)
    }

    func testProtein_case1_noWeightAnywhere() {
        assertGoldenKPIs(NutritionKPIFixtures.protein_case1_noWeightAnywhere)
    }

    func testProtein_case2_weightInRange() {
        assertGoldenKPIs(NutritionKPIFixtures.protein_case2_weightInRange)
    }

    func testProtein_case3_singleWeighInMidRange() {
        assertGoldenKPIs(NutritionKPIFixtures.protein_case3_singleWeighInMidRange)
    }

    func testProtein_case4_lowCalorieDayExcludesFromProteinMean() {
        assertGoldenKPIs(NutritionKPIFixtures.protein_case4_lowCalorieDayExcludesProteinFromMean)
    }

    func testProtein_case5_preRangeWeightFallback() {
        assertGoldenKPIs(NutritionKPIFixtures.protein_case5_preRangeWeightFallback)
    }

    private func assertGoldenKPIs(_ c: NutritionKPIFixtures.GoldenCase, file: StaticString = #filePath, line: UInt = #line) {
        let cal = NutritionKPIFixtures.isoUTCCalendar
        let filtered = NutritionKPIMath.filterMacros(c.dailyMacros, dateStart: c.dateStart, dateEnd: c.dateEnd)
        let pct = NutritionKPIMath.computeMacroPct(filtered)
        let kpis = NutritionKPIMath.computeKPIValues(
            pct, scale: c.scale, dateStart: c.dateStart, dateEnd: c.dateEnd, calendar: cal
        )

        XCTAssertEqual(kpis.last7dAvgKcal, c.expected.last7dAvgKcal, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(kpis.totalBodyFatChange, c.expected.totalBodyFatChange, file: file, line: line)
        XCTAssertEqual(kpis.totalWeightChange, c.expected.totalWeightChange, file: file, line: line)
        assertOptionalDoubleEqual(
            kpis.sevenDayProteinPerKg,
            c.expected.sevenDayProteinPerKg,
            accuracy: 1e-9,
            file: file,
            line: line
        )
    }

    private func assertOptionalDoubleEqual(
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
            XCTFail("Expected \(String(describing: expected)) for protein/kg, got \(String(describing: actual))", file: file, line: line)
        }
    }
}
