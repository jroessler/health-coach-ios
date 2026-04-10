import Foundation
import SwiftData
import Observation

@Observable
final class SyncService {
    let healthKitService = HealthKitService()
    let hevyAPIService = HevyAPIService()

    var isSyncing = false
    var syncProgress = ""
    var syncError: String?

    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastSyncDate") }
    }

    private var lastHealthKitSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastHealthKitSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastHealthKitSyncDate") }
    }

    @MainActor
    func sync(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        syncProgress = "Starting sync..."

        var errors: [String] = []

        do {
            try await syncHealthKit(modelContext: modelContext)
        } catch {
            errors.append("HealthKit: \(error.localizedDescription)")
        }

        do {
            try await syncHevy(modelContext: modelContext)
        } catch {
            errors.append("Hevy: \(error.localizedDescription)")
        }

        if errors.isEmpty {
            lastSyncDate = Date()
            syncProgress = "Sync complete!"
        } else {
            syncError = errors.joined(separator: "\n")
            syncProgress = "Sync finished with errors."
        }

        try? await Task.sleep(for: .seconds(2))
        isSyncing = false
    }

    // MARK: - HealthKit Sync
    //
    // Processes one data type at a time to keep memory bounded.
    // Each type is fetched in monthly chunks inside HealthKitService.

    @MainActor
    private func syncHealthKit(modelContext: ModelContext) async throws {
        syncProgress = "Requesting HealthKit access..."
        try await healthKitService.requestAuthorization()

        let store = HealthRecordStore.shared
        let storeIsEmpty = (try? store.countRecords()) == 0
        let since = lastHealthKitSyncDate
        let healthSince: Date? = storeIsEmpty ? nil : since
        let mappings = HealthKitService.recordTypeMappings
        var totalRecords = 0

        for (index, mapping) in mappings.enumerated() {
            let label = mapping.metric.replacingOccurrences(of: "_", with: " ")
            syncProgress = "Syncing \(label) (\(index + 1)/\(mappings.count))..."

            do {
                let count = try await healthKitService.syncHealthRecordsForType(
                    mapping: mapping,
                    since: healthSince,
                    store: store
                )
                totalRecords += count
            } catch {
                continue
            }
        }

        syncProgress = "Fetching nutrition data..."
        let nutritionCount = try await healthKitService.syncNutritionEntries(
            since: since,
            modelContext: modelContext
        )

        syncProgress = "Saved \(totalRecords) health records, \(nutritionCount) nutrition entries"
        lastHealthKitSyncDate = Date()
    }

    // MARK: - Hevy Sync

    @MainActor
    private func syncHevy(modelContext: ModelContext) async throws {
        guard let apiKey = KeychainService.shared.retrieve(), !apiKey.isEmpty else {
            syncProgress = "Skipping Hevy (no API key)..."
            return
        }

        syncProgress = "Fetching workouts from Hevy..."
        let apiWorkouts = try await hevyAPIService.fetchAllWorkouts(apiKey: apiKey)

        let existingKeys = fetchExistingWorkoutKeys(modelContext: modelContext)
        let (newWorkouts, newSets) = hevyAPIService.buildWorkoutsAndSets(
            from: apiWorkouts,
            existingKeys: existingKeys
        )

        syncProgress = "Saving \(newWorkouts.count) new workouts..."
        for workout in newWorkouts {
            modelContext.insert(workout)
        }
        for workoutSet in newSets {
            modelContext.insert(workoutSet)
        }

        syncProgress = "Fetching exercise templates..."
        let apiTemplates = try await hevyAPIService.fetchAllExerciseTemplates(apiKey: apiKey)
        let templates = hevyAPIService.buildExerciseTemplates(from: apiTemplates)

        syncProgress = "Saving \(templates.count) exercise templates..."
        for template in templates {
            modelContext.insert(template)
        }

        try modelContext.save()
    }

    private func fetchExistingWorkoutKeys(modelContext: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Workout>()
        guard let workouts = try? modelContext.fetch(descriptor) else { return [] }
        return Set(workouts.map { "\($0.title)|\($0.startTime)" })
    }
}
