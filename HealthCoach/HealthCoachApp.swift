import SwiftUI
import SwiftData

@main
struct HealthCoachApp: App {
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
        ])
    }
}

struct ContentView: View {
    private let tabBarBg = Color(hex: 0x02161C)

    var body: some View {
        TabView {
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
            HeartView()
                .tabItem {
                    Label("Heart", systemImage: "heart.text.square")
                }
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "figure.walk")
                }
        }
        .toolbarBackground(tabBarBg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .tint(Color(hex: 0x22D3EE))
    }
}
