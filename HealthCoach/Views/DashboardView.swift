import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @State private var stats: DashboardStats?
    @State private var isLoadingStats = true

    private let bgColor = Color(hex: 0x02161C)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    syncSection
                    if let stats {
                        metricsGrid(stats: stats)
                        dateRangesSection(stats: stats)
                    } else if isLoadingStats {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(bgColor.ignoresSafeArea())
            .refreshable { await performSync() }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                // Reset synchronously so the dumbbell is visible before the
                // async task even starts — prevents a stale-content flash.
                stats = nil
                isLoadingStats = true
            }
            .task {
                await loadStatsInBackground()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Health Intelligence")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Nutrition, workouts, heart & activity")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(spacing: 6) {
            Button {
                Task { await performSync() }
            } label: {
                HStack(spacing: 8) {
                    if syncService.isSyncing {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                        Text(syncService.syncProgress)
                            .font(.subheadline.weight(.medium))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Data")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(accentCyan.opacity(syncService.isSyncing ? 0.4 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(syncService.isSyncing)

            if let error = syncService.syncError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if let date = syncService.lastSyncDate {
                Text("Last synced: \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Metrics Grid

    private func metricsGrid(stats: DashboardStats) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                label: "Days of Data",
                value: stats.daysOfData.formatted(),
                subtitle: "from MacroFactor"
            )
            StatCard(
                label: "Food Entries",
                value: stats.foodEntries.formatted(),
                subtitle: "from MacroFactor"
            )
            StatCard(
                label: "Workout Sessions",
                value: stats.workoutSessions.formatted(),
                subtitle: "from Hevy"
            )
            StatCard(
                label: "Total Sets Logged",
                value: stats.totalSets.formatted(),
                subtitle: "from Hevy"
            )
            StatCard(
                label: "Health Records",
                value: stats.healthRecords.formatted(),
                subtitle: "from Apple Watch"
            )
        }
    }

    // MARK: - Per-Source Date Ranges

    private func dateRangesSection(stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let r = stats.appleRange {
                sourceRangeRow(name: "Apple Health", range: r)
            }
            if let r = stats.macroFactorRange {
                sourceRangeRow(name: "MacroFactor", range: r)
            }
            if let r = stats.hevyRange {
                sourceRangeRow(name: "Hevy", range: r)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func sourceRangeRow(name: String, range: SourceDateRange) -> some View {
        (Text(name).bold() +
         Text("  \(range.start) to \(range.end)"))
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.55))
    }

    // MARK: - Loading State

    private var loadingState: some View {
        LoadingView(message: "Computing stats…")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(accentCyan.opacity(0.5))
            Text("No data yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Tap \"Sync Data\" to pull from\nApple Health and Hevy.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Actions

    private func performSync() async {
        await syncService.sync(modelContext: modelContext)
        await loadStatsInBackground()
    }

    private func loadStatsInBackground() async {
        // Yield immediately so the main thread can finish rendering the
        // loading indicator before any synchronous @ModelActor setup runs.
        await Task.yield()
        let container = modelContext.container
        let computer = StatsComputer(modelContainer: container)
        stats = await computer.compute()
        isLoadingStats = false
    }
}

// MARK: - Background Stats Computer

@ModelActor
actor StatsComputer {
    func compute() -> DashboardStats? {
        do {
            let foodEntries = try modelContext.fetchCount(FetchDescriptor<NutritionEntry>())
            let workoutSessions = try modelContext.fetchCount(FetchDescriptor<Workout>())
            let totalSets = try modelContext.fetchCount(FetchDescriptor<WorkoutSet>())

            let store = HealthRecordStore.shared
            let healthRecords = try store.countRecords()

            let hasData = foodEntries > 0 || healthRecords > 0 || workoutSessions > 0
            guard hasData else { return nil }

            let (daysOfData, nutritionRange) = try countNutritionDays()

            let appleRange = try store.dateRange()
            let hevyRange = try dateRange(for: Workout.self)

            return DashboardStats(
                daysOfData: daysOfData,
                foodEntries: foodEntries,
                healthRecords: healthRecords,
                workoutSessions: workoutSessions,
                totalSets: totalSets,
                appleRange: SourceDateRange(min: appleRange.min, max: appleRange.max),
                macroFactorRange: SourceDateRange(min: nutritionRange.min, max: nutritionRange.max),
                hevyRange: SourceDateRange(min: hevyRange.min, max: hevyRange.max)
            )
        } catch {
            return nil
        }
    }

    private func countNutritionDays() throws -> (Int, (min: String?, max: String?)) {
        var uniqueDates = Set<String>()
        let batchSize = 5_000
        var offset = 0

        while true {
            let ctx = ModelContext(modelContainer)
            var desc = FetchDescriptor<NutritionEntry>(sortBy: [SortDescriptor(\.date)])
            desc.fetchLimit = batchSize
            desc.fetchOffset = offset
            let batch = try ctx.fetch(desc)
            if batch.isEmpty { break }

            for entry in batch {
                uniqueDates.insert(entry.date)
            }
            if batch.count < batchSize { break }
            offset += batchSize
        }

        return (uniqueDates.count, (min: uniqueDates.min(), max: uniqueDates.max()))
    }

    private func dateRange(for type: Workout.Type) throws -> (min: String?, max: String?) {
        var ascDesc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])
        ascDesc.fetchLimit = 1
        let earliest = try modelContext.fetch(ascDesc).first

        var descDesc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descDesc.fetchLimit = 1
        let latest = try modelContext.fetch(descDesc).first

        return (earliest?.date, latest?.date)
    }
}

// MARK: - Data Types

struct SourceDateRange: Sendable {
    let start: String
    let end: String

    init?(min: String?, max: String?) {
        guard let s = min, let e = max else { return nil }
        self.start = s
        self.end = e
    }
}

struct DashboardStats: Sendable {
    let daysOfData: Int
    let foodEntries: Int
    let healthRecords: Int
    let workoutSessions: Int
    let totalSets: Int
    let appleRange: SourceDateRange?
    let macroFactorRange: SourceDateRange?
    let hevyRange: SourceDateRange?
}
