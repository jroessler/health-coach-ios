import Foundation

// Mirrors health/app/shared/globals.py — nutrition-related constants only.

enum NutritionConstants {
    static let proteinKcalPerGram: Double = 4
    static let carbsKcalPerGram: Double = 4
    static let fatKcalPerGram: Double = 9

    static let dietQualityGood: Double = 0.4
    static let dietQualityOk: Double = 0.2

    static let proteinMealTargetG: Double = 30
    static let proteinPostWorkoutTargetG: Double = 40

    static let minCaloriesForFiltering: Double = 500

    static let empiricalRollingWindowDays = 14
    static let rollingWindowDays = 7
    static let kcalPerKgBodyWeight: Double = 7700

    static let preWorkoutWindowHours: Double = 4
    static let postWorkoutWindowHours: Double = 4

    static let preWorkoutTimingGoodMin = 60
    static let preWorkoutTimingGoodMax = 120
    /// X-axis for pre-workout chart: plot uses `axisMax - minutesBefore` so labels read 200→0 (Streamlit parity).
    static let preWorkoutChartAxisMaxMinutes: Double = 200
    static let postWorkoutTimingTargetMin = 120
}
