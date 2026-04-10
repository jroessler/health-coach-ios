import Foundation

// Values must stay in sync with health/app/services/settings.py (UserSettings, UserPreferences, DEFAULT_*, options).

enum StreamlitSettingsDefaults {
    static let targetProteinPct = 35
    static let targetCarbsPct = 40
    static let targetFatPct = 25
    static let fiberTargetG = 30
    static let sugarLimitG = 50
    static let weeklyWeightLossTargetKg = -0.5
    static let weeklyBodyfatLossTargetPct = -0.25
    static let weeklySetsLegs = 18
    static let weeklySetsBack = 18
    static let weeklySetsChest = 18
    static let weeklySetsShoulders = 10
    static let weeklySetsTriceps = 7
    static let weeklySetsBiceps = 7
    static let weeklySetsAbs = 8

    static let age = 32
    static let heightCm = 187.0
    static let gender = "male"
    static let trainingExperience = "Very Advanced (5+ years experience)"
    static let dietPhase = "Cutting (fat loss while preserving muscle mass)"
}

/// Mirrors `GENDER_OPTIONS` in settings.py
let streamlitGenderOptions = ["male", "female"]

/// Mirrors `TRAINING_EXPERIENCE_OPTIONS` in settings.py
let streamlitTrainingExperienceOptions = [
    "Beginner (<1 year experience)",
    "Intermediate (1-2 years experience)",
    "Advanced (2-5 years experience)",
    "Very Advanced (5+ years experience)",
]

/// Mirrors `DIET_PHASE_OPTIONS` in settings.py
let streamlitDietPhaseOptions = [
    "Cutting (fat loss while preserving muscle mass)",
    "Gaining (muscle gain while preserving body fat)",
    "Maintaining",
]

struct UserSettings: Codable, Equatable, Sendable {
    var age: Int
    var heightCm: Double
    var gender: String
    var trainingExperience: String
    var dietPhase: String

    enum CodingKeys: String, CodingKey {
        case age
        case heightCm = "height_cm"
        case gender
        case trainingExperience = "training_experience"
        case dietPhase = "diet_phase"
    }

    static func defaults() -> UserSettings {
        UserSettings(
            age: StreamlitSettingsDefaults.age,
            heightCm: StreamlitSettingsDefaults.heightCm,
            gender: StreamlitSettingsDefaults.gender,
            trainingExperience: StreamlitSettingsDefaults.trainingExperience,
            dietPhase: StreamlitSettingsDefaults.dietPhase
        )
    }

    /// Mirrors `get_user_settings()` fallbacks in settings.py
    static func mergedFromStorage(_ row: UserSettings?) -> UserSettings {
        guard let row else { return defaults() }
        return UserSettings(
            age: row.age == 0 ? StreamlitSettingsDefaults.age : row.age,
            heightCm: row.heightCm.isFinite ? row.heightCm : StreamlitSettingsDefaults.heightCm,
            gender: row.gender.isEmpty ? StreamlitSettingsDefaults.gender : row.gender,
            trainingExperience: row.trainingExperience.isEmpty
                ? StreamlitSettingsDefaults.trainingExperience : row.trainingExperience,
            dietPhase: row.dietPhase.isEmpty ? StreamlitSettingsDefaults.dietPhase : row.dietPhase
        )
    }
}

struct UserPreferences: Codable, Equatable, Sendable {
    var targetProteinPct: Int
    var targetCarbsPct: Int
    var targetFatPct: Int
    var fiberTargetG: Int
    var sugarLimitG: Int
    var weeklyWeightLossTargetKg: Double
    var weeklyBodyfatLossTargetPct: Double
    var targetSetsLegs: Int
    var targetSetsBack: Int
    var targetSetsChest: Int
    var targetSetsShoulders: Int
    var targetSetsTriceps: Int
    var targetSetsBiceps: Int
    var targetSetsAbs: Int

    enum CodingKeys: String, CodingKey {
        case targetProteinPct = "target_protein_pct"
        case targetCarbsPct = "target_carbs_pct"
        case targetFatPct = "target_fat_pct"
        case fiberTargetG = "fiber_target_g"
        case sugarLimitG = "sugar_limit_g"
        case weeklyWeightLossTargetKg = "weekly_weight_loss_target_kg"
        case weeklyBodyfatLossTargetPct = "weekly_bodyfat_loss_target_pct"
        case targetSetsLegs = "target_sets_legs"
        case targetSetsBack = "target_sets_back"
        case targetSetsChest = "target_sets_chest"
        case targetSetsShoulders = "target_sets_shoulders"
        case targetSetsTriceps = "target_sets_triceps"
        case targetSetsBiceps = "target_sets_biceps"
        case targetSetsAbs = "target_sets_abs"
    }

    static func defaults() -> UserPreferences {
        UserPreferences(
            targetProteinPct: StreamlitSettingsDefaults.targetProteinPct,
            targetCarbsPct: StreamlitSettingsDefaults.targetCarbsPct,
            targetFatPct: StreamlitSettingsDefaults.targetFatPct,
            fiberTargetG: StreamlitSettingsDefaults.fiberTargetG,
            sugarLimitG: StreamlitSettingsDefaults.sugarLimitG,
            weeklyWeightLossTargetKg: StreamlitSettingsDefaults.weeklyWeightLossTargetKg,
            weeklyBodyfatLossTargetPct: Self.roundWeeklyBodyfatPct(StreamlitSettingsDefaults.weeklyBodyfatLossTargetPct),
            targetSetsLegs: StreamlitSettingsDefaults.weeklySetsLegs,
            targetSetsBack: StreamlitSettingsDefaults.weeklySetsBack,
            targetSetsChest: StreamlitSettingsDefaults.weeklySetsChest,
            targetSetsShoulders: StreamlitSettingsDefaults.weeklySetsShoulders,
            targetSetsTriceps: StreamlitSettingsDefaults.weeklySetsTriceps,
            targetSetsBiceps: StreamlitSettingsDefaults.weeklySetsBiceps,
            targetSetsAbs: StreamlitSettingsDefaults.weeklySetsAbs
        )
    }

    /// Mirrors `get_user_preferences()` fallbacks in settings.py (`or DEFAULT` / `is not None`)
    static func mergedFromStorage(_ row: UserPreferences?) -> UserPreferences {
        guard let row else { return defaults() }
        return UserPreferences(
            targetProteinPct: row.targetProteinPct != 0 ? row.targetProteinPct : StreamlitSettingsDefaults.targetProteinPct,
            targetCarbsPct: row.targetCarbsPct != 0 ? row.targetCarbsPct : StreamlitSettingsDefaults.targetCarbsPct,
            targetFatPct: row.targetFatPct != 0 ? row.targetFatPct : StreamlitSettingsDefaults.targetFatPct,
            fiberTargetG: row.fiberTargetG != 0 ? row.fiberTargetG : StreamlitSettingsDefaults.fiberTargetG,
            sugarLimitG: row.sugarLimitG != 0 ? row.sugarLimitG : StreamlitSettingsDefaults.sugarLimitG,
            weeklyWeightLossTargetKg: row.weeklyWeightLossTargetKg.isFinite
                ? row.weeklyWeightLossTargetKg : StreamlitSettingsDefaults.weeklyWeightLossTargetKg,
            weeklyBodyfatLossTargetPct: Self.roundWeeklyBodyfatPct(
                row.weeklyBodyfatLossTargetPct.isFinite
                    ? row.weeklyBodyfatLossTargetPct : StreamlitSettingsDefaults.weeklyBodyfatLossTargetPct
            ),
            targetSetsLegs: row.targetSetsLegs != 0 ? row.targetSetsLegs : StreamlitSettingsDefaults.weeklySetsLegs,
            targetSetsBack: row.targetSetsBack != 0 ? row.targetSetsBack : StreamlitSettingsDefaults.weeklySetsBack,
            targetSetsChest: row.targetSetsChest != 0 ? row.targetSetsChest : StreamlitSettingsDefaults.weeklySetsChest,
            targetSetsShoulders: row.targetSetsShoulders != 0
                ? row.targetSetsShoulders : StreamlitSettingsDefaults.weeklySetsShoulders,
            targetSetsTriceps: row.targetSetsTriceps != 0 ? row.targetSetsTriceps : StreamlitSettingsDefaults.weeklySetsTriceps,
            targetSetsBiceps: row.targetSetsBiceps != 0 ? row.targetSetsBiceps : StreamlitSettingsDefaults.weeklySetsBiceps,
            targetSetsAbs: row.targetSetsAbs != 0 ? row.targetSetsAbs : StreamlitSettingsDefaults.weeklySetsAbs
        )
    }

    private static func roundWeeklyBodyfatPct(_ v: Double) -> Double {
        guard v.isFinite else { return StreamlitSettingsDefaults.weeklyBodyfatLossTargetPct }
        return min(0, max(-1, round(v * 10) / 10))
    }

    /// Mirrors `get_muscle_volume_targets()` in settings.py
    func muscleVolumeTargetsByRadarMuscle() -> [String: Double] {
        [
            "Legs": Double(targetSetsLegs),
            "Back": Double(targetSetsBack),
            "Chest": Double(targetSetsChest),
            "Shoulders": Double(targetSetsShoulders),
            "Triceps": Double(targetSetsTriceps),
            "Biceps": Double(targetSetsBiceps),
            "Abs": Double(targetSetsAbs),
        ]
    }
}

enum UserProfileValidation {

    static func normalizedSettingsForSave(_ s: UserSettings) -> UserSettings {
        var o = s
        o.age = min(120, max(1, s.age))
        o.heightCm = round(min(250, max(50, s.heightCm)) * 2) / 2
        if !streamlitGenderOptions.contains(o.gender) {
            o.gender = streamlitGenderOptions[0]
        }
        if !streamlitTrainingExperienceOptions.contains(o.trainingExperience) {
            o.trainingExperience = streamlitTrainingExperienceOptions[0]
        }
        if !streamlitDietPhaseOptions.contains(o.dietPhase) {
            o.dietPhase = streamlitDietPhaseOptions[0]
        }
        return o
    }

    /// Returns nil if valid; otherwise an error message matching Streamlit for macros, or a range hint.
    static func validatePreferencesForSave(_ p: UserPreferences) -> String? {
        let sum = p.targetProteinPct + p.targetCarbsPct + p.targetFatPct
        if sum != 100 {
            return
                "Macro targets must sum to 100%. Currently: Protein \(p.targetProteinPct)% + "
                + "Carbs \(p.targetCarbsPct)% + Fat \(p.targetFatPct)% = \(sum)%. "
                + "Please adjust the values so they add up to 100%."
        }
        if !(10...60).contains(p.targetProteinPct) { return "Target protein must be between 10 and 60." }
        if !(10...70).contains(p.targetCarbsPct) { return "Target carbs must be between 10 and 70." }
        if !(10...60).contains(p.targetFatPct) { return "Target fat must be between 10 and 60." }
        if !(10...80).contains(p.fiberTargetG) { return "Fiber target must be between 10 and 80 g/day." }
        if !(20...150).contains(p.sugarLimitG) { return "Sugar limit must be between 20 and 150 g/day." }
        let w = p.weeklyWeightLossTargetKg
        if w < -2.0 || w > 0.0 || !w.isFinite { return "Weekly weight loss target must be between -2.0 and 0.0 kg/wk." }
        let bf = p.weeklyBodyfatLossTargetPct
        if bf < -1.0 || bf > 0.0 || !bf.isFinite { return "Weekly body fat loss target must be between -1.0 and 0.0 %/wk." }
        let sets = [
            p.targetSetsLegs, p.targetSetsBack, p.targetSetsChest, p.targetSetsShoulders,
            p.targetSetsTriceps, p.targetSetsBiceps, p.targetSetsAbs,
        ]
        for v in sets where !(0...40).contains(v) {
            return "Weekly set targets must be between 0 and 40."
        }
        return nil
    }

    /// Apply Streamlit cast behavior: int() / float() on submit; clamp to Streamlit `number_input` bounds.
    static func normalizedPreferencesForSave(_ p: UserPreferences) -> UserPreferences {
        var o = p
        o.targetProteinPct = min(60, max(10, p.targetProteinPct))
        o.targetCarbsPct = min(70, max(10, p.targetCarbsPct))
        o.targetFatPct = min(60, max(10, p.targetFatPct))
        o.fiberTargetG = min(80, max(10, p.fiberTargetG))
        o.sugarLimitG = min(150, max(20, p.sugarLimitG))
        o.weeklyWeightLossTargetKg = min(0, max(-2, round(p.weeklyWeightLossTargetKg * 10) / 10))
        o.weeklyBodyfatLossTargetPct = min(0, max(-1, round(p.weeklyBodyfatLossTargetPct * 10) / 10))
        o.targetSetsLegs = min(40, max(0, p.targetSetsLegs))
        o.targetSetsBack = min(40, max(0, p.targetSetsBack))
        o.targetSetsChest = min(40, max(0, p.targetSetsChest))
        o.targetSetsShoulders = min(40, max(0, p.targetSetsShoulders))
        o.targetSetsTriceps = min(40, max(0, p.targetSetsTriceps))
        o.targetSetsBiceps = min(40, max(0, p.targetSetsBiceps))
        o.targetSetsAbs = min(40, max(0, p.targetSetsAbs))
        return o
    }
}
