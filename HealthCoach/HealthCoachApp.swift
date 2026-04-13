import Combine
import SwiftData
import SwiftUI

@main
struct HealthCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let syncService = SyncService()
    private let userProfileStore = UserProfileStore()
    private let _healthRecordStore = HealthRecordStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(userProfileStore)
        }
        .modelContainer(for: [
            NutritionEntry.self,
            Workout.self,
            WorkoutSet.self,
            ExerciseTemplate.self,
            CoachSummary.self,
            ChatConversation.self,
            ChatMessage.self,
        ])
    }
}

private enum MainTab: Int, Hashable {
    case nutrition = 0
    case heart = 1
    case activity = 2
    case coach = 3
}

struct ContentView: View {
    private let tabBarBg = Color(hex: 0x02161C)

    @AppStorage(CoachWeeklyReminderService.promptCompletedKey) private var weeklyReminderPromptCompleted = false
    @State private var selectedTab = MainTab.nutrition.rawValue
    @State private var showWeeklyReminderPrompt = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(MainTab.nutrition.rawValue)
            HeartView()
                .tabItem {
                    Label("Heart", systemImage: "heart.fill")
                }
                .tag(MainTab.heart.rawValue)
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "figure.walk")
                }
                .tag(MainTab.activity.rawValue)
            CoachTabView()
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }
                .tag(MainTab.coach.rawValue)
        }
        .toolbarBackground(tabBarBg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .tint(Color(hex: 0x22D3EE))
        .onAppear {
            if !weeklyReminderPromptCompleted {
                showWeeklyReminderPrompt = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .healthCoachOpenMainCoachTab)) { _ in
            selectedTab = MainTab.coach.rawValue
        }
        .alert("Weekly summary reminder?", isPresented: $showWeeklyReminderPrompt) {
            Button("Enable") {
                Task { @MainActor in
                    await CoachWeeklyReminderService.setReminderEnabled(true)
                    weeklyReminderPromptCompleted = true
                }
            }
            Button("Not Now", role: .cancel) {
                weeklyReminderPromptCompleted = true
            }
        } message: {
            Text("Get a reminder every Sunday to start your AI Coach summary. You can change this anytime in Settings.")
        }
    }
}
