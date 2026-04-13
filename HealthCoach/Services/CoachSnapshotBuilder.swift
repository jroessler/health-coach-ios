import Foundation
import SwiftData

// Builds a token-efficient, Encodable snapshot from existing computers.
// Only extracts KPI scalars and summary statistics — no raw chart point arrays.
// All computation is delegated to HeartComputer, ActivityComputer, NutritionComputer; no logic is duplicated here.

// MARK: - Top-level payload

struct CoachPayload: Encodable {
    let meta: CoachMeta
    let shortTerm: CoachPeriod
    let longTerm: CoachPeriod
    let userProfile: CoachUserProfile
    let targets: CoachTargets
}

struct CoachMeta: Encodable {
    let dateEnd: String
    let shortTermStart: String
    let longTermStart: String
    let shortTermDays: Int
    let longTermDays: Int
}

struct CoachPeriod: Encodable {
    let heart: CoachHeartSummary?
    let activity: CoachActivitySummary?
    let nutrition: CoachNutritionSummary?
}

struct CoachUserProfile: Encodable {
    let age: Int
    let heightCm: Double
    let gender: String
    let trainingExperience: String
    let dietPhase: String
}

struct CoachTargets: Encodable {
    let proteinPct: Int
    let carbsPct: Int
    let fatPct: Int
    let proteinMealTargetG: Double
    let proteinPostWorkoutTargetG: Double
    let weeklyWeightLossTargetKg: Double
    let weeklyBodyfatLossTargetPct: Double
    let stepsGoal: Double
    let standGoalMin: Double
    let activeKcalTarget: Double
    let vo2LongevityGoal: Double
    let muscleSetTargets: [String: Double]
}

// MARK: - Heart summary

struct CoachHeartSummary: Encodable {
    let recoveryScore: Int
    let hrv: CoachHRVSummary
    let rhr: CoachRHRSummary
    let divergence: CoachDivergenceSummary
    let vo2: CoachVO2Summary?
    let hrvVolumeCorrelation: CoachHRVVolumeSummary?
    let hrvPerformanceZones: CoachHRVPerformanceSummary?
    let periodDays: Int
    let baselineDaysHRV: Int
    let baselineDaysRHR: Int
}

struct CoachHRVSummary: Encodable {
    let today: Double
    let baseline: Double
    let pctDeviation: Double
    let zScore: Double
    let rollingAvg7d: Double?
}

struct CoachRHRSummary: Encodable {
    let today: Double
    let baseline: Double
    let pctDeviation: Double
    let zScore: Double
    let rollingAvg7d: Double?
}

struct CoachDivergenceSummary: Encodable {
    let value: Double
    let label: String
    let detail: String
}

struct CoachVO2Summary: Encodable {
    let current: Double
    let delta30d: Double?
    let ageLabel: String
    let below: Double
    let average: Double
    let elite: Double
    let longevityGoal: Double
}

struct CoachHRVVolumeSummary: Encodable {
    let periodDays: Int
    let recentHRV7dMean: Double?
    let recentLaggedVolumeMean: Double?
}

struct CoachHRVPerformanceSummary: Encodable {
    let p33: Double
    let p66: Double
    let avgVolumeZoneLow: Double
    let avgVolumeZoneModerate: Double
    let avgVolumeZoneHigh: Double
    let regressionSlope: Double
}

// MARK: - Activity summary

struct CoachActivitySummary: Encodable {
    let workoutKPIs: CoachWorkoutKPIs
    let activityKPIs: CoachActivityKPIs
    let muscleRadar: CoachMuscleRadar
    let energyTDEE: CoachEnergyTDEE
    let volumeProgression: CoachVolumeProgression?
}

struct CoachWorkoutKPIs: Encodable {
    let totalWorkouts: Int
    let workoutsLastN: Int
    let avgDurationOverallMin: Double
    let avgDurationLastNMin: Double
    let priorDays: Int
    let deltaWorkouts: Double
    let deltaDurationMin: Double
}

struct CoachActivityKPIs: Encodable {
    let avgSteps: Int
    let avgStandMin: Double
    let avgWalkingSpeed: Double
    let priorDays: Int
}

struct CoachMuscleRadar: Encodable {
    let adherenceRatios: [String: Double]
    let setCounts: [String: Int]
    let daysUsed: Int
}

struct CoachEnergyTDEE: Encodable {
    let avgActiveKcal: Double?
    let avgBasalKcal: Double?
    let avgTDEE: Double?
    let effectiveDays: Int
}

struct CoachVolumeProgression: Encodable {
    let muscles: [String]
    let weekLabels: [String]
    let pctChange: [[Double]]
}

// MARK: - Nutrition summary

struct CoachNutritionSummary: Encodable {
    let kpis: CoachNutritionKPIs
    let macros: CoachMacroSummary
    let calorieBalance: CoachCalorieBalance?
    let weeklyLossRates: [CoachWeeklyLoss]
    let preWorkoutAdherence: CoachWorkoutNutritionAdherence?
    let postWorkoutAdherence: CoachWorkoutNutritionAdherence?
}

struct CoachNutritionKPIs: Encodable {
    let last7dAvgKcal: Double
    let totalBodyFatChange: Double?
    let totalWeightChange: Double?
    let sevenDayProteinPerKg: Double?
}

struct CoachMacroSummary: Encodable {
    let avgProteinPct: Double?
    let avgCarbsPct: Double?
    let avgFatPct: Double?
}

struct CoachCalorieBalance: Encodable {
    let avgBalanceApple7d: Double?
    let avgBalanceEmpirical7d: Double?
    let effectiveDays: Int
}

struct CoachWeeklyLoss: Encodable {
    let weekLabel: String
    let deltaWeightKg: Double?
    let deltaBodyFatPct: Double?
}

struct CoachWorkoutNutritionAdherence: Encodable {
    let totalWorkouts: Int
    let goodCount: Int
    let okCount: Int
    let badCount: Int
}

// MARK: - Builder

struct CoachSnapshotBuilder {

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static func build(
        shortTermDays: Int,
        longTermDays: Int,
        modelContainer: ModelContainer,
        settings: UserSettings,
        preferences: UserPreferences
    ) async -> CoachPayload {

        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        let shortStart = cal.date(byAdding: .day, value: -(shortTermDays - 1), to: today) ?? today
        let longStart  = cal.date(byAdding: .day, value: -(longTermDays  - 1), to: today) ?? today

        let muscleTargets = preferences.muscleVolumeTargetsByRadarMuscle()

        // Run all six compute calls concurrently
        async let shortHeartTask   = HeartComputer(modelContainer: modelContainer).compute(dateStart: shortStart, dateEnd: today, userAge: settings.age)
        async let longHeartTask    = HeartComputer(modelContainer: modelContainer).compute(dateStart: longStart,  dateEnd: today, userAge: settings.age)
        async let shortActivityTask = ActivityComputer(modelContainer: modelContainer).compute(dateStart: shortStart, dateEnd: today, muscleTargets: muscleTargets)
        async let longActivityTask  = ActivityComputer(modelContainer: modelContainer).compute(dateStart: longStart,  dateEnd: today, muscleTargets: muscleTargets)
        async let shortNutritionTask = NutritionComputer(modelContainer: modelContainer).compute(dateStart: shortStart, dateEnd: today)
        async let longNutritionTask  = NutritionComputer(modelContainer: modelContainer).compute(dateStart: longStart,  dateEnd: today)

        let (shortHeart, longHeart, shortActivity, longActivity, shortNutrition, longNutrition) = await (
            shortHeartTask, longHeartTask, shortActivityTask, longActivityTask, shortNutritionTask, longNutritionTask
        )

        let meta = CoachMeta(
            dateEnd: dateFmt.string(from: today),
            shortTermStart: dateFmt.string(from: shortStart),
            longTermStart: dateFmt.string(from: longStart),
            shortTermDays: shortTermDays,
            longTermDays: longTermDays
        )

        let userProfile = CoachUserProfile(
            age: settings.age,
            heightCm: settings.heightCm,
            gender: settings.gender,
            trainingExperience: settings.trainingExperience,
            dietPhase: settings.dietPhase
        )

        let targets = CoachTargets(
            proteinPct: preferences.targetProteinPct,
            carbsPct: preferences.targetCarbsPct,
            fatPct: preferences.targetFatPct,
            proteinMealTargetG: NutritionConstants.proteinMealTargetG,
            proteinPostWorkoutTargetG: NutritionConstants.proteinPostWorkoutTargetG,
            weeklyWeightLossTargetKg: preferences.weeklyWeightLossTargetKg,
            weeklyBodyfatLossTargetPct: preferences.weeklyBodyfatLossTargetPct,
            stepsGoal: ActivityConstants.stepsGoal,
            standGoalMin: ActivityConstants.standGoalMin,
            activeKcalTarget: ActivityConstants.activeKcalTarget,
            vo2LongevityGoal: HeartConstants.vo2LongevityGoal,
            muscleSetTargets: muscleTargets
        )

        return CoachPayload(
            meta: meta,
            shortTerm: CoachPeriod(
                heart: shortHeart.map(heartSummary),
                activity: shortActivity.map(activitySummary),
                nutrition: shortNutrition.map(nutritionSummary)
            ),
            longTerm: CoachPeriod(
                heart: longHeart.map(heartSummary),
                activity: longActivity.map { snap in activitySummaryWithProgression(snap) },
                nutrition: longNutrition.map(nutritionSummary)
            ),
            userProfile: userProfile,
            targets: targets
        )
    }

    // MARK: - Heart extraction

    private static func heartSummary(_ snap: HeartSnapshot) -> CoachHeartSummary {
        let k = snap.recoveryKPIs
        let f = snap.fitnessKPIs

        let hrv7dRolling: Double? = {
            let vals = snap.hrv.points.compactMap(\.hrv7d)
            guard !vals.isEmpty else { return nil }
            return vals.suffix(7).reduce(0, +) / Double(min(7, vals.count))
        }()

        let rhr7dRolling: Double? = {
            let vals = snap.rhr.points.compactMap(\.rhr7d)
            guard !vals.isEmpty else { return nil }
            return vals.suffix(7).reduce(0, +) / Double(min(7, vals.count))
        }()

        let vo2Summary: CoachVO2Summary? = f.vo2Current.map { current in
            CoachVO2Summary(
                current: current,
                delta30d: f.vo2Delta30d,
                ageLabel: f.vo2AgeRefs.ageLabel,
                below: f.vo2AgeRefs.below,
                average: f.vo2AgeRefs.average,
                elite: f.vo2AgeRefs.elite,
                longevityGoal: HeartConstants.vo2LongevityGoal
            )
        }

        let hrvVolSummary: CoachHRVVolumeSummary? = snap.hrvVolume.map { vol in
            let recentHRV = vol.points.suffix(14).compactMap(\.hrv7d)
            let recentVol = vol.points.suffix(14).compactMap(\.laggedVolume)
            return CoachHRVVolumeSummary(
                periodDays: vol.averagePeriod,
                recentHRV7dMean: recentHRV.isEmpty ? nil : recentHRV.reduce(0, +) / Double(recentHRV.count),
                recentLaggedVolumeMean: recentVol.isEmpty ? nil : recentVol.reduce(0, +) / Double(recentVol.count)
            )
        }

        let hrvPerfSummary: CoachHRVPerformanceSummary? = snap.hrvPerformance.map { perf in
            CoachHRVPerformanceSummary(
                p33: perf.p33,
                p66: perf.p66,
                avgVolumeZoneLow: perf.zoneAverages.low,
                avgVolumeZoneModerate: perf.zoneAverages.moderate,
                avgVolumeZoneHigh: perf.zoneAverages.high,
                regressionSlope: perf.regressionSlope
            )
        }

        return CoachHeartSummary(
            recoveryScore: k.recoveryScore,
            hrv: CoachHRVSummary(
                today: k.hrvToday,
                baseline: k.hrvBaseline,
                pctDeviation: k.hrvPct,
                zScore: k.hrvZ,
                rollingAvg7d: hrv7dRolling
            ),
            rhr: CoachRHRSummary(
                today: k.rhrToday,
                baseline: k.rhrBaseline,
                pctDeviation: k.rhrPct,
                zScore: k.rhrZ,
                rollingAvg7d: rhr7dRolling
            ),
            divergence: CoachDivergenceSummary(
                value: k.divergence,
                label: k.divergenceLabel,
                detail: k.divergenceDetail
            ),
            vo2: vo2Summary,
            hrvVolumeCorrelation: hrvVolSummary,
            hrvPerformanceZones: hrvPerfSummary,
            periodDays: snap.periodLength,
            baselineDaysHRV: snap.baselineDaysHRV,
            baselineDaysRHR: snap.baselineDaysRHR
        )
    }

    // MARK: - Activity extraction

    private static func activitySummary(_ snap: ActivitySnapshot) -> CoachActivitySummary {
        activitySummaryWithProgression(snap, includeProgression: false)
    }

    private static func activitySummaryWithProgression(_ snap: ActivitySnapshot, includeProgression: Bool = true) -> CoachActivitySummary {
        let energyPoints = snap.energyTDEE.points
        let avgActive: Double? = {
            let vals = energyPoints.map(\.activeKcal)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }()
        let avgBasal: Double? = {
            let vals = energyPoints.map(\.basalKcal)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }()
        let avgTDEE: Double? = {
            let vals = energyPoints.compactMap(\.tdee)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }()

        let progression: CoachVolumeProgression? = includeProgression ? CoachVolumeProgression(
            muscles: snap.volumeProgression.muscles,
            weekLabels: snap.volumeProgression.weekLabels,
            pctChange: snap.volumeProgression.pctChange
        ) : nil

        return CoachActivitySummary(
            workoutKPIs: CoachWorkoutKPIs(
                totalWorkouts: snap.workoutKPIs.totalWorkouts,
                workoutsLastN: snap.workoutKPIs.workoutsLastN,
                avgDurationOverallMin: snap.workoutKPIs.avgDurationOverallMin,
                avgDurationLastNMin: snap.workoutKPIs.avgDurationLastNMin,
                priorDays: snap.workoutKPIs.priorDays,
                deltaWorkouts: snap.workoutKPIs.deltaWorkouts,
                deltaDurationMin: snap.workoutKPIs.deltaDurationMin
            ),
            activityKPIs: CoachActivityKPIs(
                avgSteps: snap.activityKPIs.avgSteps,
                avgStandMin: snap.activityKPIs.avgStandMin,
                avgWalkingSpeed: snap.activityKPIs.avgWalkingSpeed,
                priorDays: snap.activityKPIs.priorDays
            ),
            muscleRadar: CoachMuscleRadar(
                adherenceRatios: snap.muscleRadar.currentRatios,
                setCounts: snap.muscleRadar.currentCounts,
                daysUsed: snap.muscleRadar.daysUsed
            ),
            energyTDEE: CoachEnergyTDEE(
                avgActiveKcal: avgActive,
                avgBasalKcal: avgBasal,
                avgTDEE: avgTDEE,
                effectiveDays: snap.energyTDEE.effectiveDays
            ),
            volumeProgression: progression
        )
    }

    // MARK: - Nutrition extraction

    private static func nutritionSummary(_ snap: NutritionSnapshot) -> CoachNutritionSummary {
        let balanceSummary: CoachCalorieBalance? = snap.calorieBalance.map { bal in
            let apple7d = bal.points.compactMap(\.balanceApple7d)
            let emp7d   = bal.points.compactMap(\.balanceEmpirical7d)
            return CoachCalorieBalance(
                avgBalanceApple7d: apple7d.isEmpty ? nil : apple7d.reduce(0, +) / Double(apple7d.count),
                avgBalanceEmpirical7d: emp7d.isEmpty ? nil : emp7d.reduce(0, +) / Double(emp7d.count),
                effectiveDays: bal.effectiveDays
            )
        }

        let recentLossRates: [CoachWeeklyLoss] = snap.weeklyLossRates.map { data in
            data.points.suffix(6).map { pt in
                CoachWeeklyLoss(
                    weekLabel: pt.weekLabel,
                    deltaWeightKg: pt.deltaWeightKg,
                    deltaBodyFatPct: pt.deltaBodyFatPct
                )
            }
        } ?? []

        let preAdherence: CoachWorkoutNutritionAdherence? = snap.preWorkout.isEmpty ? nil : {
            let good = snap.preWorkout.filter { $0.timingQuality == .good }.count
            let ok   = snap.preWorkout.filter { $0.timingQuality == .ok }.count
            let bad  = snap.preWorkout.filter { $0.timingQuality == .bad }.count
            return CoachWorkoutNutritionAdherence(totalWorkouts: snap.preWorkout.count, goodCount: good, okCount: ok, badCount: bad)
        }()

        let postAdherence: CoachWorkoutNutritionAdherence? = snap.postWorkout.isEmpty ? nil : {
            let good = snap.postWorkout.filter { $0.quadrant == .good }.count
            let ok   = snap.postWorkout.filter { $0.quadrant == .ok }.count
            let bad  = snap.postWorkout.filter { $0.quadrant == .bad }.count
            return CoachWorkoutNutritionAdherence(totalWorkouts: snap.postWorkout.count, goodCount: good, okCount: ok, badCount: bad)
        }()

        return CoachNutritionSummary(
            kpis: CoachNutritionKPIs(
                last7dAvgKcal: snap.kpis.last7dAvgKcal,
                totalBodyFatChange: snap.kpis.totalBodyFatChange,
                totalWeightChange: snap.kpis.totalWeightChange,
                sevenDayProteinPerKg: snap.kpis.sevenDayProteinPerKg
            ),
            macros: CoachMacroSummary(
                avgProteinPct: snap.macroTargets.avgProteinPct,
                avgCarbsPct: snap.macroTargets.avgCarbsPct,
                avgFatPct: snap.macroTargets.avgFatPct
            ),
            calorieBalance: balanceSummary,
            weeklyLossRates: recentLossRates,
            preWorkoutAdherence: preAdherence,
            postWorkoutAdherence: postAdherence
        )
    }
}
