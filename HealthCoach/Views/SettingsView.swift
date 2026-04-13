import SwiftUI
import HealthKit

struct SettingsView: View {
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput = ""
    @State private var isKeyVisible = false
    @State private var keySaved = false
    @State private var anthropicKeyInput = ""
    @State private var isAnthropicKeyVisible = false
    @State private var anthropicKeySaved = false
    @State private var healthKitAuthorized = false
    @State private var weeklyCoachReminderEnabled = UserDefaults.standard.bool(
        forKey: CoachWeeklyReminderService.enabledKey
    )

    private let bgColor = Color(hex: 0x02161C)
    private let cardBg = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        NavigationStack {
            List {
                profileSection
                hevySection
                aiCoachSection
                weeklyReminderSection
                healthKitSection
                syncSection
                dataSection
            }
            .scrollContentBackground(.hidden)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(accentCyan)
                }
            }
            .onAppear {
                if let existing = KeychainService.shared.retrieve() {
                    apiKeyInput = existing
                }
                if let existing = KeychainService.shared.retrieveAnthropicKey() {
                    anthropicKeyInput = existing
                }
                healthKitAuthorized = HKHealthStore.isHealthDataAvailable()
                weeklyCoachReminderEnabled = UserDefaults.standard.bool(forKey: CoachWeeklyReminderService.enabledKey)
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            NavigationLink {
                PersonalSettingsView()
            } label: {
                Label("Personal information", systemImage: "person.fill")
            }
            .listRowBackground(cardBg)

            NavigationLink {
                NutritionPreferencesView()
            } label: {
                Label("Nutrition targets", systemImage: "leaf.fill")
            }
            .listRowBackground(cardBg)

            NavigationLink {
                TrainingVolumeTargetsView()
            } label: {
                Label("Training volume (sets/week)", systemImage: "figure.strengthtraining.traditional")
            }
            .listRowBackground(cardBg)
        } header: {
            Text("Profile")
        } footer: {
            Text("Profile and targets are stored only on this device.")
        }
    }

    // MARK: - Hevy API Key

    private var hevySection: some View {
        Section {
            HStack {
                Group {
                    if isKeyVisible {
                        TextField("Hevy API Key", text: $apiKeyInput)
                    } else {
                        SecureField("Hevy API Key", text: $apiKeyInput)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    isKeyVisible.toggle()
                } label: {
                    Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(cardBg)

            Button {
                let success = KeychainService.shared.save(apiKey: apiKeyInput)
                keySaved = success
            } label: {
                HStack {
                    Image(systemName: keySaved ? "checkmark.circle.fill" : "key.fill")
                    Text(keySaved ? "Key Saved" : "Save API Key")
                }
                .foregroundStyle(keySaved ? .green : accentCyan)
            }
            .listRowBackground(cardBg)
        } header: {
            Text("Hevy")
        } footer: {
            Text("Your API key is stored securely in the iOS Keychain.")
        }
    }

    // MARK: - AI Coach API Key

    private var aiCoachSection: some View {
        Section {
            HStack {
                Group {
                    if isAnthropicKeyVisible {
                        TextField("Anthropic API Key", text: $anthropicKeyInput)
                    } else {
                        SecureField("Anthropic API Key", text: $anthropicKeyInput)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    isAnthropicKeyVisible.toggle()
                } label: {
                    Image(systemName: isAnthropicKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(cardBg)

            Button {
                let success = KeychainService.shared.saveAnthropicKey(anthropicKeyInput)
                anthropicKeySaved = success
            } label: {
                HStack {
                    Image(systemName: anthropicKeySaved ? "checkmark.circle.fill" : "key.fill")
                    Text(anthropicKeySaved ? "Key Saved" : "Save API Key")
                }
                .foregroundStyle(anthropicKeySaved ? .green : accentCyan)
            }
            .listRowBackground(cardBg)
        } header: {
            Text("AI Coach")
        } footer: {
            Text("Your Anthropic API key is stored securely in the iOS Keychain. Required for the AI Coach tab.")
        }
    }

    // MARK: - Weekly reminder

    private var weeklyReminderSection: some View {
        Section {
            Toggle(isOn: $weeklyCoachReminderEnabled) {
                Label("Weekly summary reminder", systemImage: "bell.badge")
            }
            .onChange(of: weeklyCoachReminderEnabled) { _, new in
                Task { @MainActor in
                    let applied = await CoachWeeklyReminderService.setReminderEnabled(new)
                    if applied != new {
                        weeklyCoachReminderEnabled = applied
                    }
                }
            }
            .listRowBackground(cardBg)
        } header: {
            Text("Reminders")
        } footer: {
            Text("Sundays at 10:00. Tap the notification to open the Coach tab.")
        }
    }

    // MARK: - HealthKit Status

    private var healthKitSection: some View {
        Section {
            HStack {
                Label("HealthKit", systemImage: "heart.fill")
                Spacer()
                Text(healthKitAuthorized ? "Available" : "Not Available")
                    .foregroundStyle(healthKitAuthorized ? .green : .red)
            }
            .listRowBackground(cardBg)
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Health data permissions are requested when you sync. You can manage them in Settings > Health > Data Access.")
        }
    }

    // MARK: - Sync Status

    private var syncSection: some View {
        Section {
            if let date = syncService.lastSyncDate {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(date, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(cardBg)
            }

            Button {
                Task { await syncService.sync(modelContext: modelContext) }
            } label: {
                HStack {
                    if syncService.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(accentCyan)
                        Text(syncService.syncProgress)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                }
                .foregroundStyle(accentCyan)
            }
            .disabled(syncService.isSyncing)
            .listRowBackground(cardBg)

            if let error = syncService.syncError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .listRowBackground(cardBg)
            }
        } header: {
            Text("Sync")
        }
    }

    // MARK: - Data Management

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                clearAllData()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Local Data")
                }
            }
            .listRowBackground(cardBg)
        } header: {
            Text("Data")
        } footer: {
            Text("This removes all cached data from the app. Your Apple Health and Hevy data remain untouched.")
        }
    }

    private func clearAllData() {
        do {
            try HealthRecordStore.shared.deleteAllRecords()
            try modelContext.delete(model: NutritionEntry.self)
            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: WorkoutSet.self)
            try modelContext.delete(model: ExerciseTemplate.self)
            try modelContext.save()
            UserDefaults.standard.removeObject(forKey: "lastSyncDate")
            UserDefaults.standard.removeObject(forKey: "lastHealthKitSyncDate")
        } catch {
            syncService.syncError = "Failed to clear data: \(error.localizedDescription)"
        }
    }
}
