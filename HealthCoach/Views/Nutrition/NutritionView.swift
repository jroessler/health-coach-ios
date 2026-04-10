import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

    @State private var snapshot: NutritionSnapshot?
    @State private var isLoading = false
    @State private var dateStart = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var dateEnd = Date()
    @State private var loadTask: Task<Void, Never>?

    private let bgColor = Color(hex: 0x02161C)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateRangePicker
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadData() }
            .onChange(of: dateStart) { scheduleLoad() }
            .onChange(of: dateEnd) { scheduleLoad() }
        }
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    DatePicker("", selection: $dateStart, in: ...dateEnd, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(accentCyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TO")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    DatePicker("", selection: $dateEnd, in: dateStart..., displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(accentCyan)
                }

                Spacer()

                Menu {
                    Button("Last 7 days") { setRange(days: 7) }
                    Button("Last 14 days") { setRange(days: 14) }
                    Button("Last 30 days") { setRange(days: 30) }
                    Button("Last 60 days") { setRange(days: 60) }
                    Button("Last 90 days") { setRange(days: 90) }
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(accentCyan)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var content: some View {
        if isLoading && snapshot == nil {
            loadingState
        } else if let snapshot {
            nutritionContent(snapshot)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func nutritionContent(_ data: NutritionSnapshot) -> some View {
        // KPIs
        NutritionKPIGrid(kpis: data.kpis)

        ChartSection(
            title: "Macro Overview",
            description: NutritionDescriptions.macroStackedBars
        ) {
            MacroTargetBars(data: data.macroTargets, preferences: profileStore.preferences)
        }

        ChartSection(
            title: "Daily Calories + Macros",
            description: NutritionDescriptions.dailyCaloriesMacros
        ) {
            DailyCaloriesMacrosChart(data: data.dailyCaloriesMacros)
        }

        // Calorie Intake vs TDEE
        if let balance = data.calorieBalance {
            ChartSection(
                title: "Calorie Intake vs TDEE",
                description: NutritionDescriptions.calorieIntakeVsTDEE
            ) {
                CalorieBalanceChart(data: balance)
            }
        }

        // Weight & Body Fat Trends
        if let weights = data.weightTrends {
            ChartSection(
                title: "Weight & Body Fat Trends",
                description: NutritionDescriptions.weightDualAxis
            ) {
                WeightTrendsChart(data: weights)
            }
        }

        // Weekly Loss Rates
        if let loss = data.weeklyLossRates {
            ChartSection(
                title: "Weekly Loss Rates",
                description: NutritionDescriptions.weightLossRates
            ) {
                WeeklyLossRateChart(data: loss, preferences: profileStore.preferences)
            }
        }

        // Pre & Post Workout Nutrition
        let preDesc = NutritionDescriptions.preWorkoutNutritionTiming(avgWeightKg: data.avgWeightKg ?? 0)
        ChartSection(
            title: "Pre-Workout Nutrition",
            description: preDesc
        ) {
            PreWorkoutChart(
                points: data.preWorkout,
                targets: data.preWorkoutTargets
            )
        }

        ChartSection(
            title: "Post-Workout Nutrition",
            description: NutritionDescriptions.postWorkoutNutritionTiming
        ) {
            PostWorkoutChart(points: data.postWorkout)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(accentCyan)
                .controlSize(.large)
            Text("Computing nutrition data...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(accentCyan.opacity(0.5))
            Text("No nutrition data")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Sync your data from the Home tab\nto see nutrition insights.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Actions

    private func setRange(days: Int) {
        dateEnd = Date()
        dateStart = Calendar.current.date(byAdding: .day, value: -(days - 1), to: dateEnd)!
    }

    private func scheduleLoad() {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        snapshot = nil
        let container = modelContext.container
        let computer = NutritionComputer(modelContainer: container)
        let start = Calendar.current.startOfDay(for: dateStart)
        let end = Calendar.current.startOfDay(for: dateEnd)
        snapshot = await computer.compute(dateStart: start, dateEnd: end)
        isLoading = false
    }
}
