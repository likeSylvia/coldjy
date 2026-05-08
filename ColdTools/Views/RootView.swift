import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = LockStore()
    @State private var selectedTab: AppTab = .dashboard

    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings {
        settingsList.first ?? AppSettingsStore.current(in: context)
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tabItem { Label("首页", systemImage: "house.fill") }
                    .tag(AppTab.dashboard)

                QuitSmokingView()
                    .tabItem { Label("戒烟", systemImage: "nosign") }
                    .tag(AppTab.smoking)

                WaterView()
                    .tabItem { Label("喝水", systemImage: "drop.fill") }
                    .tag(AppTab.water)

                RecordsView()
                    .tabItem { Label("记录", systemImage: "list.bullet.rectangle") }
                    .tag(AppTab.records)

                SettingsView()
                    .tabItem { Label("设置", systemImage: "gear") }
                    .tag(AppTab.settings)
            }
            .onChange(of: selectedTab) { _, _ in Haptics.selection() }

            if lock.state == .locked {
                LockScreen(lock: lock, settings: settings)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .environment(lock)
        .task {
            // 确保存在默认设置
            let current = AppSettingsStore.current(in: context)
            lock.evaluateOnLaunch(settings: current)
            if current.waterRemindersEnabled {
                await NotificationScheduler.rescheduleWaterReminders(settings: current)
            }
        }
        .onChange(of: scenePhase) { _, new in
            switch new {
            case .background, .inactive:
                lock.markBackgrounded()
            case .active:
                lock.checkReLock(settings: settings)
            @unknown default: break
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.state)
    }
}

enum AppTab: Hashable {
    case dashboard, smoking, water, records, settings
}
