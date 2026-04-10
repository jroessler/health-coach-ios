import SwiftUI
import SwiftData

@main
struct HealthCoachApp: App {
    let syncService = SyncService()
    private let userProfileStore = UserProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
                .environment(userProfileStore)
        }
        .modelContainer(for: [
            HealthRecord.self,
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
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "square.grid.2x2")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .toolbarBackground(tabBarBg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .tint(Color(hex: 0x22D3EE))
    }
}
