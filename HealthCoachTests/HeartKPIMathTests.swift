import XCTest
@testable import HealthCoach

/// Goldens for `HeartKPIMath` — see `docs/heart-computations.md`.
final class HeartKPIMathTests: XCTestCase {

    private var cal: Calendar { HeartKPIMath.calendar }

    private func sod(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - HRV & RHR baseline rolling (Step 4)

    func testLeftRollingMean_sevenEqualAt50_index6_baseline50_sd0() {
        let v = Array(repeating: 50.0, count: 7)
        let means = HeartKPIMath.leftRollingMean(v, window: 30, minPeriods: 7)
        let sds = HeartKPIMath.leftRollingStd(v, window: 30, minPeriods: 7, fillZero: true)
        XCTAssertEqual(means[6]!, 50, accuracy: 1e-9)
        XCTAssertEqual(sds[6]!, 0, accuracy: 1e-9)
    }

    func testLeftRollingMean_std_sevenDistinct_docExample3_index6() {
        let v: [Double] = [40, 42, 44, 46, 48, 50, 52]
        let means = HeartKPIMath.leftRollingMean(v, window: 30, minPeriods: 7)
        let sds = HeartKPIMath.leftRollingStd(v, window: 30, minPeriods: 7, fillZero: true)
        XCTAssertEqual(means[6]!, 46, accuracy: 1e-9)
        XCTAssertEqual(sds[6]!, 4.320493798938574, accuracy: 1e-6)
    }

    func testLeftRollingMean_sixPoints_allNilMean() {
        let v = Array(repeating: 1.0, count: 6)
        let means = HeartKPIMath.leftRollingMean(v, window: 30, minPeriods: 7)
        XCTAssertTrue(means.allSatisfy { $0 == nil })
    }

    // MARK: - §7 HRV 7d rolling

    func testHRV7d_sevenEqualDays_all50() {
        let v = Array(repeating: 50.0, count: 7)
        let hrv7d = HeartKPIMath.leftRollingMean(v, window: 7, minPeriods: 1)
        for i in 0..<7 {
            XCTAssertEqual(hrv7d[i]!, 50, accuracy: 1e-9, "index \(i)")
        }
    }

    func testHRV7d_increasing40to46_lastMatchesDocRolling() {
        let v: [Double] = [40, 41, 42, 43, 44, 45, 46]
        let hrv7d = HeartKPIMath.leftRollingMean(v, window: 7, minPeriods: 1)
        let last = hrv7d[6]!
        let expected = HeartKPIMath.mean(v) // full window = mean 40…46
        XCTAssertEqual(last, expected, accuracy: 1e-9)
    }

    // MARK: - §1 Recovery score

    func testRecoveryScore_docExample1_bothAtBaseline() {
        let hrvPts = sevenUniformHRV(mean: 50, baseline: 50, sd: 10)
        let rhrPts = sevenUniformRHR(mean: 55, baseline: 55, sd: 5)
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.recoveryScore, 50)
        XCTAssertEqual(k.hrvZ, 0, accuracy: 1e-9)
        XCTAssertEqual(k.rhrZ, 0, accuracy: 1e-9)
    }

    func testRecoveryScore_docExample2_hrvZ08_rhrZ08() {
        let base = sod(2026, 1, 1)
        var hrvPts: [HRVDayPoint] = []
        var rhrPts: [RHRDayPoint] = []
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i, to: base)!
            // hrvZ = (58 − 50) / 10 = 0.8
            hrvPts.append(makeHRVDayPoint(date: d, hrv: 58, baseline: 50, sd: 10))
            // rhrZ = (55 − 47) / 10 = 0.8
            rhrPts.append(makeRHRDayPoint(date: d, rhr: 47, baseline: 55, sd: 10))
        }
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.recoveryScore, 70)
    }

    // MARK: - §2 HRV vs baseline

    func testHRVKPIs_docExample1_pct0_z0() {
        let hrvPts = sevenUniformHRV(mean: 50, baseline: 50, sd: 10)
        let rhrPts = sevenUniformRHR(mean: 55, baseline: 55, sd: 5)
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.hrvToday, 50, accuracy: 1e-9)
        XCTAssertEqual(k.hrvPct, 0, accuracy: 1e-9)
        XCTAssertEqual(k.hrvZ, 0, accuracy: 1e-9)
    }

    func testHRVKPIs_docExample2_pct20_z2() {
        let hrvPts = sevenUniformHRV(mean: 60, baseline: 50, sd: 5)
        let rhrPts = sevenUniformRHR(mean: 55, baseline: 55, sd: 5)
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.hrvToday, 60, accuracy: 1e-9)
        XCTAssertEqual(k.hrvPct, 20.0, accuracy: 1e-9)
        XCTAssertEqual(k.hrvZ, 2.0, accuracy: 1e-9)
    }

    func testHRVKPIs_shortRange_threeDays_meanUsesOnlyRange() {
        let d0 = sod(2026, 2, 1)
        let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
        let d2 = cal.date(byAdding: .day, value: 2, to: d0)!
        let hrvPts = [
            makeHRVDayPoint(date: d0, hrv: 48, baseline: nil, sd: 0),
            makeHRVDayPoint(date: d1, hrv: 50, baseline: nil, sd: 0),
            makeHRVDayPoint(date: d2, hrv: 52, baseline: 50, sd: 5),
        ]
        let rhrPts = [
            makeRHRDayPoint(date: d0, rhr: 55, baseline: nil, sd: 0),
            makeRHRDayPoint(date: d1, rhr: 55, baseline: nil, sd: 0),
            makeRHRDayPoint(date: d2, rhr: 55, baseline: 55, sd: 5),
        ]
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.hrvToday, 50, accuracy: 1e-9)
    }

    // MARK: - §3 RHR vs baseline

    func testRHRKPIs_docExample1_pct0_z0() {
        let hrvPts = sevenUniformHRV(mean: 50, baseline: 50, sd: 10)
        let rhrPts = sevenUniformRHR(mean: 55, baseline: 55, sd: 5)
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.rhrToday, 55, accuracy: 1e-9)
        XCTAssertEqual(k.rhrPct, 0, accuracy: 1e-9)
        XCTAssertEqual(k.rhrZ, 0, accuracy: 1e-9)
    }

    func testRHRKPIs_docExample2_pct182_zNeg2() {
        let hrvPts = sevenUniformHRV(mean: 50, baseline: 50, sd: 10)
        let rhrPts = sevenUniformRHR(mean: 65, baseline: 55, sd: 5)
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.rhrToday, 65, accuracy: 1e-9)
        XCTAssertEqual(k.rhrPct, 18.2, accuracy: 1e-9)
        XCTAssertEqual(k.rhrZ, -2.0, accuracy: 1e-9)
    }

    // MARK: - §4 Signal

    func testDivergenceSignal_docExample1_neutral() {
        let (label, detail) = HeartKPIMath.divergenceSignal(0)
        XCTAssertEqual(label, "Neutral")
        XCTAssertEqual(detail, "No clear signal")
    }

    func testDivergenceSignal_docExample2_optimal() {
        // hrvZ = 1.0, rhrZRaw = −0.5 → divergence 1.5
        let (label, _) = HeartKPIMath.divergenceSignal(1.5)
        XCTAssertEqual(label, "Optimal")
    }

    func testDivergence_hrvZ_minus_rhrZRaw_docAlgebra() {
        let hrvPts = sevenUniformHRV(mean: 60, baseline: 50, sd: 10) // hrvZ = 1
        let rhrPts = sevenUniformRHR(mean: 50, baseline: 55, sd: 10) // rhrZRaw = -0.5, rhrZ = +0.5
        let k = HeartKPIMath.computeRecoveryKPIs(hrvPoints: hrvPts, rhrPoints: rhrPts)
        XCTAssertEqual(k.hrvZ, 1.0, accuracy: 1e-9)
        XCTAssertEqual(k.divergence, 1.5, accuracy: 1e-9)
    }

    // MARK: - §6 VO₂ delta

    func testVo2Delta30d_docExample1() {
        let d = HeartKPIMath.vo2Delta30d(lastBaseline: 46, last14d: 45)
        XCTAssertEqual(d!, 1.0, accuracy: 1e-9)
    }

    func testVo2Delta30d_docExample2() {
        let d = HeartKPIMath.vo2Delta30d(lastBaseline: 44, last14d: 46)
        XCTAssertEqual(d!, -2.0, accuracy: 1e-9)
    }

    func testVo2Delta30d_nilWhenEitherMissing() {
        XCTAssertNil(HeartKPIMath.vo2Delta30d(lastBaseline: 44, last14d: nil))
        XCTAssertNil(HeartKPIMath.vo2Delta30d(lastBaseline: nil, last14d: 46))
    }

    // MARK: - §13 Lagged training volume

    func testLaggedVolume_docExample1_monday1000_tuesday0_wednesday() {
        let wed = sod(2026, 3, 3)
        let tue = cal.date(byAdding: .day, value: -1, to: wed)!
        let mon = cal.date(byAdding: .day, value: -2, to: wed)!
        let vol: [Date: Double] = [mon: 1000, tue: 0]
        let lag1 = vol[cal.date(byAdding: .day, value: -1, to: wed)!]
        let lag2 = vol[cal.date(byAdding: .day, value: -2, to: wed)!]
        XCTAssertEqual(HeartKPIMath.laggedTrainingVolume(volLag1: lag1, volLag2: lag2), 1000)
    }

    func testLaggedVolume_docExample2_day0Only_day1UsesMax() {
        let d0 = sod(2026, 4, 1)
        let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
        let vol: [Date: Double] = [d0: 500]
        let lag1 = vol[cal.date(byAdding: .day, value: -1, to: d1)!]
        let lag2 = vol[cal.date(byAdding: .day, value: -2, to: d1)!]
        XCTAssertEqual(HeartKPIMath.laggedTrainingVolume(volLag1: lag1, volLag2: lag2), 500)
    }

    // MARK: - §14 HRV vs performance (percentile + regression)

    func testPercentile_fivePoints_linearInterpolation() {
        let xs = [30.0, 40, 50, 60, 70]
        let p33 = HeartKPIMath.percentile(xs, p: 0.33)
        let p66 = HeartKPIMath.percentile(xs, p: 0.66)
        XCTAssertEqual(p33, 43.2, accuracy: 1e-9)
        XCTAssertEqual(p66, 56.4, accuracy: 1e-9)
    }

    func testLinearRegression_flatVolume_zeroSlope() {
        let hrv = [30.0, 40, 50, 60, 70]
        let vol = Array(repeating: 1000.0, count: 5)
        let (slope, _) = HeartKPIMath.linearRegression(x: hrv, y: vol)
        XCTAssertEqual(slope, 0, accuracy: 1e-9)
    }

    // MARK: - Helpers

    private func sevenUniformHRV(mean: Double, baseline: Double, sd: Double) -> [HRVDayPoint] {
        let base = sod(2026, 6, 1)
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: base)!
            return makeHRVDayPoint(date: d, hrv: mean, baseline: baseline, sd: sd)
        }
    }

    private func sevenUniformRHR(mean: Double, baseline: Double, sd: Double) -> [RHRDayPoint] {
        let base = sod(2026, 6, 1)
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: base)!
            return makeRHRDayPoint(date: d, rhr: mean, baseline: baseline, sd: sd)
        }
    }

    private func makeHRVDayPoint(date: Date, hrv: Double, baseline: Double?, sd: Double) -> HRVDayPoint {
        let b = baseline
        let u = b.map { $0 + sd }
        let l = b.map { $0 - sd }
        let l2 = b.map { $0 - 2 * sd }
        return HRVDayPoint(
            date: date,
            hrv: hrv,
            hrv7d: nil,
            baseline: baseline,
            sd: sd,
            upper: u,
            lower: l,
            lower2: l2,
            pctDev: nil
        )
    }

    private func makeRHRDayPoint(date: Date, rhr: Double, baseline: Double?, sd: Double) -> RHRDayPoint {
        let b = baseline
        let u = b.map { $0 + sd }
        let u2 = b.map { $0 + 2 * sd }
        let l = b.map { $0 - sd }
        return RHRDayPoint(
            date: date,
            rhr: rhr,
            rhr7d: nil,
            baseline: baseline,
            sd: sd,
            upper: u,
            upper2: u2,
            lower: l
        )
    }
}
