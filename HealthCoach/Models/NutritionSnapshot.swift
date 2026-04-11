import Foundation

// Pure Sendable data structs produced by NutritionComputer.
// Views bind directly to these; the AI coach/summary will also consume them.

struct NutritionSnapshot: Sendable {
    let kpis: NutritionKPIs
    let macroTargets: MacroTargetData
    let dailyCaloriesMacros: DailyCaloriesMacrosData
    let calorieBalance: CalorieBalanceData?
    let weightTrends: WeightTrendsData?
    let weeklyLossRates: WeeklyLossRateData?
    let preWorkout: [PreWorkoutPoint]
    let postWorkout: [PostWorkoutPoint]
    let avgWeightKg: Double?
    let preWorkoutTargets: PreWorkoutTargets?
}

// MARK: - KPIs

struct NutritionKPIs: Sendable {
    let last7dAvgKcal: Double
    let totalBodyFatChange: Double?
    let totalWeightChange: Double?
    /// `nil` when no usable body weight (none in range and none before the range).
    let sevenDayProteinPerKg: Double?
}

// MARK: - Macro Target Distribution

struct MacroTargetData: Sendable {
    let avgProteinPct: Double?
    let avgCarbsPct: Double?
    let avgFatPct: Double?
}

// MARK: - Daily Calories + Macros Chart

struct DailyCaloriesMacrosData: Sendable {
    let points: [DailyMacroPoint]
    let effectiveDays: Int
}

struct DailyMacroPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let proteinKcal: Double
    let carbsKcal: Double
    let fatKcal: Double
    let proteinPct: Double
    let carbsPct: Double
    let fatPct: Double
    let rollingAvgKcal: Double?
}

// MARK: - Calorie Balance Chart

struct CalorieBalanceData: Sendable {
    let points: [CalorieBalancePoint]
    let effectiveDays: Int
}

struct CalorieBalancePoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let balanceApple: Double?
    let balanceApple7d: Double?
    let balanceEmpirical7d: Double?
}

// MARK: - Weight & Body Fat Trends Chart

struct WeightTrendsData: Sendable {
    let points: [WeightTrendPoint]
    let effectiveDays: Int
}

struct WeightTrendPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let weightRolling7d: Double?
    let fatPctRolling7d: Double?
    let ffmRolling7d: Double?
}

// MARK: - Weekly Loss Rates Chart

struct WeeklyLossRateData: Sendable {
    let points: [WeeklyLossPoint]
}

struct WeeklyLossPoint: Sendable, Identifiable {
    let id = UUID()
    let weekStart: Date
    let weekLabel: String
    let deltaWeightKg: Double?
    let deltaBodyFatPct: Double?
}

// MARK: - Pre/Post Workout Nutrition

struct PreWorkoutTargets: Sendable {
    let proteinTargetG: Double
    let carbsTargetG: Double
}

enum WorkoutTimingQuality: String, Sendable {
    case good, ok, bad
}

struct PreWorkoutPoint: Sendable, Identifiable {
    let id = UUID()
    let workoutDate: Date
    let minutesBefore: Int
    let proteinG: Double
    let carbsG: Double
    let calories: Double
    let fatG: Double
    let timingQuality: WorkoutTimingQuality
}

struct PostWorkoutPoint: Sendable, Identifiable {
    let id = UUID()
    let workoutDate: Date
    let minutesAfter: Int
    let proteinG: Double
    let carbsG: Double
    let calories: Double
    let fatG: Double
    let quadrant: WorkoutTimingQuality
}
