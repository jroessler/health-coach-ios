import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

    @State private var snapshot: ActivitySnapshot?
    @State private var isLoading = true
    @State private var dateStart = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var dateEnd = Date()
    @State private var loadTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var showHome = false

    private let bgColor    = Color(hex: 0x02161C)
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
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHome = true
                    } label: {
                        Image(systemName: "house")
                            .foregroundStyle(accentCyan)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(accentCyan)
                    }
                }
            }
            .sheet(isPresented: $showHome) {
                DashboardView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                snapshot = nil
                isLoading = true
            }
            .task { await loadData() }
            .onChange(of: dateStart) { scheduleLoad() }
            .onChange(of: dateEnd)   { scheduleLoad() }
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
                    Button("Last 7 days")  { setRange(days: 7) }
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

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if isLoading && snapshot == nil {
            loadingState
        } else if let snapshot {
            activityContent(snapshot)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func activityContent(_ data: ActivitySnapshot) -> some View {

        // ── Workouts section ──────────────────────────────────────────────────
        sectionHeader("Workouts")

        WorkoutKPIGrid(kpis: data.workoutKPIs)

        ChartSection(
            title: "Muscle Distribution",
            description: ActivityDescriptions.muscleRadar(daysUsed: data.muscleRadar.daysUsed)
        ) {
            VStack(spacing: 0) {
                MuscleRadarChart(data: data.muscleRadar)
                MuscleRadarChart(data: data.muscleRadar).legendView
                    .padding(.bottom, 8)
            }
        }

        ChartSection(
            title: "Volume Progression",
            description: ActivityDescriptions.volumeProgression
        ) {
            VolumeProgressionChart(data: data.volumeProgression)
        }

        // ── Activity section ──────────────────────────────────────────────────
        sectionHeader("Activity")

        ActivityKPIGrid(kpis: data.activityKPIs)

        ChartSection(
            title: "Energy (TDEE)",
            description: ActivityDescriptions.energyTDEE
        ) {
            EnergyTDEEChart(data: data.energyTDEE)
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - States

    private var loadingState: some View {
        LoadingView(message: "Computing activity data…")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(accentCyan.opacity(0.5))
            Text("No activity data")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Sync your data from the Home tab\nto see activity insights.")
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
        await Task.yield()
        let container = modelContext.container
        let targets = profileStore.preferences.muscleVolumeTargetsByRadarMuscle()
        let computer = ActivityComputer(modelContainer: container)
        let start = Calendar.current.startOfDay(for: dateStart)
        let end   = Calendar.current.startOfDay(for: dateEnd)
        snapshot = await computer.compute(dateStart: start, dateEnd: end, muscleTargets: targets)
        isLoading = false
    }
}
