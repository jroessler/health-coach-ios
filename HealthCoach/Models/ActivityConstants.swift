import Foundation

// Mirrors health/app/shared/globals.py — activity & workout constants only.

enum ActivityConstants {
    // MARK: - Activity goals (from globals.py)

    static let stepsGoal: Double = 10_000
    static let stepsOk: Double = 7_000

    static let standGoalMin: Double = 180
    static let standOkMin: Double = 90

    static let daylightGoalMin: Double = 60
    static let daylightOkMin: Double = 30

    static let walkSpeedGoal: Double = 4.0
    static let walkSpeedOk: Double = 3.0

    static let activeKcalTarget: Double = 600

    // MARK: - Energy filter thresholds (compute_activity)

    static let minBasalKcal: Double = 1_000
    static let minActiveKcal: Double = 50

    // MARK: - Rolling window

    static let rollingWindowDays: Int = 7

    // MARK: - Muscle radar

    static let maxRadarDays: Int = 30

    /// Ordered list of coarse muscle groups — matches RADAR_MUSCLES in globals.py.
    static let radarMuscles: [String] = [
        "Legs", "Back", "Chest", "Shoulders", "Triceps", "Biceps", "Abs"
    ]

    /// Fine-to-coarse muscle mapping — exact copy of HEVY_MUSCLE_MAP in globals.py.
    static let hevyMuscleMap: [String: String] = [
        "adductors":    "Legs",
        "quadriceps":   "Legs",
        "hamstrings":   "Legs",
        "calves":       "Legs",
        "glutes":       "Legs",
        "abductors":    "Legs",
        "chest":        "Chest",
        "shoulders":    "Shoulders",
        "traps":        "Shoulders",
        "triceps":      "Triceps",
        "lats":         "Back",
        "upper_back":   "Back",
        "lower_back":   "Back",
        "biceps":       "Biceps",
        "abdominals":   "Abs",
    ]

    // MARK: - Volume progression

    static let volumeWeeks: Int = 6

    // MARK: - KPI colors

    static let colorGood = 0x10B981   // green
    static let colorOk   = 0xFBBF24   // amber
    static let colorBad  = 0xF97316   // orange
    static let colorNeutral = 0x22D3EE // cyan
}
