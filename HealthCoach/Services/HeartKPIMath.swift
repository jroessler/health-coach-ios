import Foundation

// Pure heart math — shared by `HeartComputer` and unit tests.
// Mirrors `docs/heart-computations.md` and `heart.py`.

enum HeartKPIMath {

    static let calendar: Calendar = Calendar(identifier: .iso8601)

    // MARK: - Rolling windows

    /// Left-aligned rolling mean (pandas default, min_periods support).
    static func leftRollingMean(_ values: [Double], window: Int, minPeriods: Int) -> [Double?] {
        let n = values.count
        return (0..<n).map { i in
            let start = max(0, i - window + 1)
            let slice = Array(values[start...i])
            return slice.count >= minPeriods ? slice.reduce(0, +) / Double(slice.count) : nil
        }
    }

    /// Left-aligned rolling mean for optional values (skips nils).
    static func leftRollingMeanOptional(_ values: [Double?], window: Int, minPeriods: Int) -> [Double?] {
        let n = values.count
        return (0..<n).map { i in
            let start = max(0, i - window + 1)
            let slice = values[start...i].compactMap { $0 }
            return slice.count >= minPeriods ? slice.reduce(0, +) / Double(slice.count) : nil
        }
    }

    /// Left-aligned rolling std (ddof = 1). `fillZero`: return 0 when std path is skipped (matches `heart.py` fillna).
    static func leftRollingStd(_ values: [Double], window: Int, minPeriods: Int, fillZero: Bool) -> [Double?] {
        let n = values.count
        return (0..<n).map { i in
            let start = max(0, i - window + 1)
            let slice = Array(values[start...i])
            if slice.count < max(minPeriods, 2) {
                return fillZero ? 0 : nil
            }
            let mean = slice.reduce(0, +) / Double(slice.count)
            let variance = slice.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(slice.count - 1)
            let std = sqrt(variance)
            return fillZero ? std : std
        }
    }

    static func forwardFill(_ arr: inout [Double?]) {
        for i in 1..<arr.count {
            if arr[i] == nil { arr[i] = arr[i - 1] }
        }
    }

    // MARK: - Recovery KPIs

    static func computeRecoveryKPIs(
        hrvPoints: [HRVDayPoint],
        rhrPoints: [RHRDayPoint]
    ) -> RecoveryKPIs {
        let defaultKPIs = RecoveryKPIs(
            recoveryScore: 50,
            hrvToday: 0, hrvBaseline: 0, hrvPct: 0, hrvZ: 0,
            rhrToday: 0, rhrBaseline: 0, rhrPct: 0, rhrZ: 0,
            divergence: 0, divergenceLabel: "Neutral", divergenceDetail: "No clear signal"
        )

        guard !hrvPoints.isEmpty, !rhrPoints.isEmpty else { return defaultKPIs }

        let hrvValid = hrvPoints
        let hrvLast7Mean = mean(hrvValid.suffix(7).map(\.hrv))
        let latestHRV = hrvValid.last!

        let latestBaselineHRV = latestHRV.baseline ?? 0
        let latestSD_HRV = latestHRV.sd
        let hrvZ = latestSD_HRV > 0 ? (hrvLast7Mean - latestBaselineHRV) / latestSD_HRV : 0
        let hrvPct: Double = latestBaselineHRV > 0
            ? rounded((hrvLast7Mean - latestBaselineHRV) / latestBaselineHRV * 100, decimals: 1)
            : 0

        let rhrValid = rhrPoints
        let rhrLast7Mean = mean(rhrValid.suffix(7).map(\.rhr))
        let latestRHR = rhrValid.last!

        let latestBaselineRHR = latestRHR.baseline ?? 0
        let latestSD_RHR = latestRHR.sd

        let rhrZ = latestSD_RHR > 0 ? (latestBaselineRHR - rhrLast7Mean) / latestSD_RHR : 0
        let rhrPct: Double = latestBaselineRHR > 0
            ? rounded((rhrLast7Mean - latestBaselineRHR) / latestBaselineRHR * 100, decimals: 1)
            : 0

        let recoveryRaw = (hrvZ + rhrZ) / 2
        let recoveryScore = Int(max(0, min(100, rounded(50 + recoveryRaw * 25, decimals: 0))))

        let rhrZRaw = latestSD_RHR > 0 ? (rhrLast7Mean - latestBaselineRHR) / latestSD_RHR : 0
        let divergence = hrvZ - rhrZRaw

        let (divergenceLabel, divergenceDetail) = divergenceSignal(divergence)

        return RecoveryKPIs(
            recoveryScore: recoveryScore,
            hrvToday: hrvLast7Mean,
            hrvBaseline: latestBaselineHRV,
            hrvPct: hrvPct,
            hrvZ: hrvZ,
            rhrToday: rhrLast7Mean,
            rhrBaseline: latestBaselineRHR,
            rhrPct: rhrPct,
            rhrZ: rhrZ,
            divergence: divergence,
            divergenceLabel: divergenceLabel,
            divergenceDetail: divergenceDetail
        )
    }

    static func divergenceSignal(_ divergence: Double) -> (String, String) {
        if divergence >= 1.0 { return ("Optimal", "HRV↑ · RHR↓") }
        if divergence >= 0.25 { return ("Aligned", "HRV↑ · RHR↓") }
        if divergence >= -0.25 { return ("Neutral", "No clear signal") }
        if divergence >= -1.0 { return ("Diverging", "HRV↓ · RHR↑") }
        return ("Stressed", "HRV↓ · RHR↑")
    }

    // MARK: - Fitness (VO₂ delta)

    /// `last baseline − last 14d mean` (§6).
    static func vo2Delta30d(lastBaseline: Double?, last14d: Double?) -> Double? {
        guard let b = lastBaseline, let v = last14d else { return nil }
        return b - v
    }

    // MARK: - HRV vs volume (lag)

    static func laggedTrainingVolume(volLag1: Double?, volLag2: Double?) -> Double? {
        switch (volLag1, volLag2) {
        case let (v1?, v2?): return max(v1, v2)
        case let (v1?, nil): return v1
        case let (nil, v2?): return v2
        default: return nil
        }
    }

    // MARK: - Stats

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = p * Double(sorted.count - 1)
        let lo = Int(floor(index))
        let hi = min(lo + 1, sorted.count - 1)
        let fraction = index - Double(lo)
        return sorted[lo] * (1 - fraction) + sorted[hi] * fraction
    }

    static func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
        guard x.count == y.count, x.count >= 2 else { return (0, 0) }
        let xMean = mean(x)
        let yMean = mean(y)
        let numerator = zip(x, y).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +)
        let denominator = x.map { ($0 - xMean) * ($0 - xMean) }.reduce(0, +)
        guard denominator > 0 else { return (0, yMean) }
        let slope = numerator / denominator
        let intercept = yMean - slope * xMean
        return (slope, intercept)
    }

    static func rounded(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }
}
