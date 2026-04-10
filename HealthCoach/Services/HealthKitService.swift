import Foundation
import HealthKit
import SwiftData

final class HealthKitService {
    private let healthStore = HKHealthStore()

    // MARK: - Type Mappings (mirrors parse_apple_health.py RECORD_TYPES)

    struct RecordTypeMapping {
        let identifier: HKQuantityTypeIdentifier
        let category: String
        let metric: String
        let displayUnit: String
        let hkUnit: HKUnit
    }

    static let recordTypeMappings: [RecordTypeMapping] = [
        // Heart
        .init(identifier: .heartRate, category: "heart", metric: "heart_rate", displayUnit: "count/min",
              hkUnit: HKUnit.count().unitDivided(by: .minute())),
        .init(identifier: .restingHeartRate, category: "heart", metric: "resting_heart_rate", displayUnit: "count/min",
              hkUnit: HKUnit.count().unitDivided(by: .minute())),
        .init(identifier: .heartRateVariabilitySDNN, category: "heart", metric: "hrv", displayUnit: "ms",
              hkUnit: HKUnit.secondUnit(with: .milli)),
        .init(identifier: .vo2Max, category: "heart", metric: "vo2_max", displayUnit: "mL/min·kg",
              hkUnit: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))),
        .init(identifier: .walkingHeartRateAverage, category: "heart", metric: "walking_heart_rate_avg", displayUnit: "count/min",
              hkUnit: HKUnit.count().unitDivided(by: .minute())),
        // Respiratory
        .init(identifier: .oxygenSaturation, category: "respiratory", metric: "blood_oxygen", displayUnit: "%",
              hkUnit: .percent()),
        .init(identifier: .respiratoryRate, category: "respiratory", metric: "respiratory_rate", displayUnit: "count/min",
              hkUnit: HKUnit.count().unitDivided(by: .minute())),
        // Activity
        .init(identifier: .activeEnergyBurned, category: "activity", metric: "active_energy", displayUnit: "kcal",
              hkUnit: .kilocalorie()),
        .init(identifier: .basalEnergyBurned, category: "activity", metric: "basal_energy", displayUnit: "kcal",
              hkUnit: .kilocalorie()),
        .init(identifier: .stepCount, category: "activity", metric: "steps", displayUnit: "count",
              hkUnit: .count()),
        .init(identifier: .appleExerciseTime, category: "activity", metric: "exercise_minutes", displayUnit: "min",
              hkUnit: .minute()),
        .init(identifier: .appleStandTime, category: "activity", metric: "stand_minutes", displayUnit: "min",
              hkUnit: .minute()),
        .init(identifier: .walkingSpeed, category: "activity", metric: "walking_speed", displayUnit: "km/hr",
              hkUnit: HKUnit.meterUnit(with: .kilo).unitDivided(by: .hour())),
        .init(identifier: .timeInDaylight, category: "activity", metric: "time_in_daylight", displayUnit: "min",
              hkUnit: .minute()),
        // Body
        .init(identifier: .bodyMass, category: "body", metric: "weight_kg", displayUnit: "kg",
              hkUnit: .gramUnit(with: .kilo)),
        .init(identifier: .bodyFatPercentage, category: "body", metric: "body_fat_pct", displayUnit: "%",
              hkUnit: .percent()),
        .init(identifier: .appleWalkingSteadiness, category: "body", metric: "walking_steadiness", displayUnit: "%",
              hkUnit: .percent()),
    ]

    // MARK: - Nutrition type mappings (mirrors parse_apple_health.py NUTRITION_TYPES)

    static let nutritionTypeMappings: [(HKQuantityTypeIdentifier, HKUnit)] = [
        (.dietaryEnergyConsumed, .kilocalorie()),
        (.dietaryProtein, .gram()),
        (.dietaryCarbohydrates, .gram()),
        (.dietaryFatTotal, .gram()),
        (.dietaryFatSaturated, .gram()),
        (.dietaryFatPolyunsaturated, .gram()),
        (.dietaryFatMonounsaturated, .gram()),
        (.dietaryFiber, .gram()),
        (.dietarySugar, .gram()),
        (.dietaryCholesterol, .gramUnit(with: .milli)),
        (.dietarySodium, .gramUnit(with: .milli)),
        (.dietaryWater, .literUnit(with: .milli)),
        (.dietaryVitaminA, .gramUnit(with: .micro)),
        (.dietaryVitaminC, .gramUnit(with: .milli)),
        (.dietaryVitaminD, .gramUnit(with: .micro)),
        (.dietaryVitaminE, .gramUnit(with: .milli)),
        (.dietaryVitaminK, .gramUnit(with: .micro)),
        (.dietaryVitaminB6, .gramUnit(with: .milli)),
        (.dietaryVitaminB12, .gramUnit(with: .micro)),
        (.dietaryThiamin, .gramUnit(with: .milli)),
        (.dietaryRiboflavin, .gramUnit(with: .milli)),
        (.dietaryNiacin, .gramUnit(with: .milli)),
        (.dietaryFolate, .gramUnit(with: .micro)),
        (.dietaryPantothenicAcid, .gramUnit(with: .milli)),
        (.dietaryIron, .gramUnit(with: .milli)),
        (.dietaryCalcium, .gramUnit(with: .milli)),
        (.dietaryMagnesium, .gramUnit(with: .milli)),
        (.dietaryPotassium, .gramUnit(with: .milli)),
        (.dietaryZinc, .gramUnit(with: .milli)),
        (.dietaryPhosphorus, .gramUnit(with: .milli)),
        (.dietaryManganese, .gramUnit(with: .milli)),
        (.dietaryCopper, .gramUnit(with: .milli)),
        (.dietarySelenium, .gramUnit(with: .micro)),
    ]

    // MARK: - Date Formatters

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    // MARK: - Authorization

    var allReadTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        for mapping in Self.recordTypeMappings {
            types.insert(HKQuantityType(mapping.identifier))
        }
        for (identifier, _) in Self.nutritionTypeMappings {
            types.insert(HKQuantityType(identifier))
        }
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: allReadTypes)
    }

    // MARK: - Batched Health Record Sync
    //
    // Processes one data type at a time, in monthly chunks, to avoid
    // loading millions of samples into memory simultaneously.

    @MainActor
    func syncHealthRecordsForType(
        mapping: RecordTypeMapping,
        since sinceDate: Date?,
        modelContext: ModelContext
    ) async throws -> Int {
        let quantityType = HKQuantityType(mapping.identifier)

        let queryStart: Date
        if let sinceDate {
            queryStart = sinceDate
        } else {
            guard let earliest = try await earliestSampleDate(for: quantityType) else {
                return 0
            }
            queryStart = earliest
        }

        let calendar = Calendar.current
        let now = Date()
        var current = queryStart
        var count = 0

        while current < now {
            let chunkEnd = min(calendar.date(byAdding: .month, value: 1, to: current)!, now)
            let predicate = HKQuery.predicateForSamples(
                withStart: current, end: chunkEnd, options: .strictStartDate
            )

            let samples: [HKQuantitySample] = try await querySamples(
                type: quantityType, predicate: predicate
            )

            for sample in samples {
                let record = HealthRecord(
                    category: mapping.category,
                    metric: mapping.metric,
                    value: sample.quantity.doubleValue(for: mapping.hkUnit),
                    unit: mapping.displayUnit,
                    source: sample.sourceRevision.source.name,
                    startDate: Self.isoFormatter.string(from: sample.startDate),
                    endDate: Self.isoFormatter.string(from: sample.endDate),
                    date: Self.dayFormatter.string(from: sample.startDate)
                )
                modelContext.insert(record)
            }
            count += samples.count

            if !samples.isEmpty {
                try modelContext.save()
            }

            current = chunkEnd
        }

        return count
    }

    // MARK: - Nutrition Entries (smaller dataset, single query is fine)

    @MainActor
    func syncNutritionEntries(
        since sinceDate: Date?,
        modelContext: ModelContext
    ) async throws -> Int {
        let foodType = HKCorrelationType(.food)
        let predicate = sinceDate.map {
            HKQuery.predicateForSamples(withStart: $0, end: nil, options: .strictStartDate)
        }

        let correlations: [HKCorrelation] = try await querySamples(
            type: foodType, predicate: predicate
        )

        for correlation in correlations {
            let foodName = (correlation.metadata?[HKMetadataKeyFoodType] as? String) ?? ""
            let startDateStr = Self.isoFormatter.string(from: correlation.startDate)
            let dateStr = Self.dayFormatter.string(from: correlation.startDate)

            let entry = NutritionEntry(foodName: foodName, startDate: startDateStr, date: dateStr)

            for object in correlation.objects {
                guard let sample = object as? HKQuantitySample else { continue }
                Self.setNutrientValue(entry, from: sample)
            }

            modelContext.insert(entry)
        }

        if !correlations.isEmpty {
            try modelContext.save()
        }

        return correlations.count
    }

    // MARK: - Helpers

    private func earliestSampleDate(for type: HKSampleType) async throws -> Date? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.first?.startDate)
                }
            }
            healthStore.execute(query)
        }
    }

    private func querySamples<T: HKSample>(type: HKSampleType, predicate: NSPredicate?) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [T]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private static func setNutrientValue(_ entry: NutritionEntry, from sample: HKQuantitySample) {
        let id = sample.quantityType.identifier

        for (identifier, unit) in nutritionTypeMappings {
            guard id == identifier.rawValue else { continue }
            let value = sample.quantity.doubleValue(for: unit)

            switch identifier {
            case .dietaryEnergyConsumed:       entry.energyKcal = value
            case .dietaryProtein:              entry.proteinG = value
            case .dietaryCarbohydrates:        entry.carbsG = value
            case .dietaryFatTotal:             entry.fatTotalG = value
            case .dietaryFatSaturated:         entry.fatSaturatedG = value
            case .dietaryFatPolyunsaturated:   entry.fatPolyunsaturatedG = value
            case .dietaryFatMonounsaturated:   entry.fatMonounsaturatedG = value
            case .dietaryFiber:                entry.fiberG = value
            case .dietarySugar:                entry.sugarG = value
            case .dietaryCholesterol:          entry.cholesterolMg = value
            case .dietarySodium:               entry.sodiumMg = value
            case .dietaryWater:                entry.waterMl = value
            case .dietaryVitaminA:             entry.vitaminAMcg = value
            case .dietaryVitaminC:             entry.vitaminCMg = value
            case .dietaryVitaminD:             entry.vitaminDMcg = value
            case .dietaryVitaminE:             entry.vitaminEMg = value
            case .dietaryVitaminK:             entry.vitaminKMcg = value
            case .dietaryVitaminB6:            entry.vitaminB6Mg = value
            case .dietaryVitaminB12:           entry.vitaminB12Mcg = value
            case .dietaryThiamin:              entry.thiaminMg = value
            case .dietaryRiboflavin:           entry.riboflavinMg = value
            case .dietaryNiacin:               entry.niacinMg = value
            case .dietaryFolate:               entry.folateMcg = value
            case .dietaryPantothenicAcid:      entry.pantothenicAcidMg = value
            case .dietaryIron:                 entry.ironMg = value
            case .dietaryCalcium:              entry.calciumMg = value
            case .dietaryMagnesium:            entry.magnesiumMg = value
            case .dietaryPotassium:            entry.potassiumMg = value
            case .dietaryZinc:                 entry.zincMg = value
            case .dietaryPhosphorus:           entry.phosphorusMg = value
            case .dietaryManganese:            entry.manganeseMg = value
            case .dietaryCopper:               entry.copperMg = value
            case .dietarySelenium:             entry.seleniumMcg = value
            default: break
            }
            return
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        }
    }
}
