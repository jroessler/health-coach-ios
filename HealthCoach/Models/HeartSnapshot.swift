import Foundation

// Pure Sendable data structs produced by HeartComputer.
// Views bind directly to these; the AI coach will also consume them.

struct HeartSnapshot: Sendable {
    let recoveryKPIs: RecoveryKPIs
    let fitnessKPIs: FitnessKPIs
    let hrv: HRVChartData
    let rhr: RHRChartData
    let vo2: VO2ChartData
    let vo2Weight: VO2WeightData?
    let hrvVolume: HRVVolumeData?
    let hrvPerformance: HRVPerformanceData?
    let periodLength: Int
    let baselineDaysHRV: Int
    let baselineDaysRHR: Int
    let baselineDaysVO2: Int
}

// MARK: - Recovery KPIs

struct RecoveryKPIs: Sendable {
    let recoveryScore: Int
    let hrvToday: Double
    let hrvBaseline: Double
    let hrvPct: Double
    let hrvZ: Double
    let rhrToday: Double
    let rhrBaseline: Double
    let rhrPct: Double
    let rhrZ: Double
    let divergence: Double
    let divergenceLabel: String
    let divergenceDetail: String
}

// MARK: - Fitness KPIs

struct FitnessKPIs: Sendable {
    let vo2Current: Double?
    let vo2Delta30d: Double?
    let vo2AgeRefs: VO2AgeRefs
}

struct VO2AgeRefs: Sendable {
    let ageLabel: String
    let below: Double
    let average: Double
    let elite: Double
}

// MARK: - HRV Chart Data

struct HRVChartData: Sendable {
    let points: [HRVDayPoint]
    let baselineDays: Int
    let averagePeriod: Int
}

struct HRVDayPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let hrv: Double
    let hrv7d: Double?
    let baseline: Double?
    let sd: Double
    let upper: Double?
    let lower: Double?
    let lower2: Double?
    let pctDev: Double?

    var sdZone: SDZone {
        guard baseline != nil, let lower, let lower2, sd > 0 else { return .normal }
        if hrv >= lower { return .normal }
        if hrv >= lower2 { return .stress }
        return .recovery
    }
}

// MARK: - RHR Chart Data

struct RHRChartData: Sendable {
    let points: [RHRDayPoint]
    let baselineDays: Int
    let averagePeriod: Int
}

struct RHRDayPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let rhr: Double
    let rhr7d: Double?
    let baseline: Double?
    let sd: Double
    let upper: Double?
    let upper2: Double?
    let lower: Double?

    var sdZone: SDZone {
        guard baseline != nil, let upper, let upper2, sd > 0 else { return .normal }
        if rhr <= upper { return .normal }
        if rhr <= upper2 { return .stress }
        return .recovery
    }
}

// MARK: - VO2 Chart Data

struct VO2ChartData: Sendable {
    let points: [VO2DayPoint]
    let baselineDays: Int
    let averagePeriod: Int
}

struct VO2DayPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let vo2Max: Double
    let vo214d: Double?
    let baseline: Double?
}

// MARK: - VO2 Weight Chart Data

struct VO2WeightData: Sendable {
    let points: [VO2WeightPoint]
}

struct VO2WeightPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double?
    let weight7d: Double?
    let weightFfill: Double?
    let vo2Max: Double?
    let vo2Baseline: Double?
    let vo2Absolute: Double?
    let vo2Absolute14d: Double?
}

// MARK: - HRV vs Training Volume

struct HRVVolumeData: Sendable {
    let points: [HRVVolumePoint]
    let averagePeriod: Int
}

struct HRVVolumePoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let hrv: Double?
    let hrv7d: Double?
    let laggedVolume: Double?
}

// MARK: - HRV vs Performance (scatter)

struct HRVPerformanceData: Sendable {
    let points: [HRVPerformancePoint]
    let p33: Double
    let p66: Double
    let zoneAverages: ZoneAverages
    let regressionSlope: Double
    let regressionIntercept: Double
}

struct HRVPerformancePoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let hrv: Double
    let volume: Double
    let zone: HRVZone
}

struct ZoneAverages: Sendable {
    let low: Double
    let moderate: Double
    let high: Double
}

// MARK: - Enums

enum SDZone: Sendable {
    case normal, stress, recovery
}

enum HRVZone: String, Sendable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}
