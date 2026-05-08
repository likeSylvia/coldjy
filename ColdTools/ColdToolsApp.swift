import SwiftUI
import SwiftData

@main
struct ColdToolsApp: App {
    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        do {
            let schema = Schema([
                SmokingLog.self,
                CravingLog.self,
                WaterLog.self,
                HealthLog.self,
                WorkLog.self,
                MemoNote.self,
                AppSettings.self,
                UnlockedAchievement.self,
            ])
            let config = ModelConfiguration(
                "ColdToolsDB",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tint(.accentColor)
        }
    }
}
