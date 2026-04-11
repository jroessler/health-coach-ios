import Foundation

// Pure Sendable data structs produced by ActivityComputer.
// Views bind directly to these; the AI coach will also consume them.

struct ActivitySnapshot: Sendable {
    let workoutKPIs: WorkoutKPIs
    let muscleRadar: MuscleRadarData
    let volumeProgression: VolumeProgressionData
    let activityKPIs: ActivityKPIs
    let energyTDEE: EnergyTDEEData
}

// MARK: - Workout KPIs

struct WorkoutKPIs: Sendable {
    let totalWorkouts: Int
    let workoutsLastN: Int
    let avgDurationOverallMin: Double
    let avgDurationPriorMin: Double
    let priorDays: Int
    let deltaWorkouts: Double
    let deltaDurationMin: Double
}

// MARK: - Muscle Radar

struct MuscleRadarData: Sendable {
    /// Coarse muscle name → raw set count for current window.
    let currentCounts: [String: Int]
    /// Coarse muscle name → raw set count for prior window.
    let previousCounts: [String: Int]
    /// Adherence ratio (0–1.5) for current window, keyed by coarse muscle.
    let currentRatios: [String: Double]
    /// Adherence ratio (0–1.5) for prior window, keyed by coarse muscle.
    let previousRatios: [String: Double]
    /// Days used (min(rangeDays, 30)).
    let daysUsed: Int
}

// MARK: - Volume Progression

struct VolumeProgressionData: Sendable {
    /// Ordered list of coarse muscle names (rows).
    let muscles: [String]
    /// Ordered list of week-range labels, e.g. "28.04.25 - 04.05.25" (columns).
    let weekLabels: [String]
    /// [muscle][week] percentage change vs prior week. Uses same indexing as muscles/weekLabels.
    let pctChange: [[Double]]
    /// [muscle][week] absolute volume (kg × reps) for hover / tooltip.
    let weeklyVolume: [[Double]]
    /// [muscle][week] prior-week volume for tooltip.
    let priorVolume: [[Double]]
}

// MARK: - Activity KPIs

struct ActivityKPIs: Sendable {
    let avgSteps: Int
    let avgStandMin: Double
    let avgWalkingSpeed: Double
    let priorDays: Int
}

// MARK: - Energy / TDEE

struct EnergyTDEEData: Sendable {
    let points: [EnergyPoint]
    let effectiveDays: Int
}

struct EnergyPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let activeKcal: Double
    let basalKcal: Double
    /// Centered 7-day rolling mean of activeKcal; nil when insufficient data.
    let activeKcal7d: Double?
    /// TDEE = activeKcal7d + basalKcal (for the rolling line).
    var tdee: Double? { activeKcal7d.map { $0 + basalKcal } }
}
