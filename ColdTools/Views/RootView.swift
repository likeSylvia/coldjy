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
                Tab("首页", systemImage: "house.fill", value: AppTab.dashboard) {
                    DashboardView(selectedTab: $selectedTab)
                }
                Tab("戒烟", systemImage: "nosign", value: AppTab.smoking) {
                    QuitSmokingView()
                }
                Tab("喝水", systemImage: "drop.fill", value: AppTab.water) {
                    WaterView()
                }
                Tab("记录", systemImage: "list.bullet.rectangle", value: AppTab.records) {
                    RecordsView()
                }
                Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsView()
                }
            }
            .onChange(of: selectedTab) { _, _ in Haptics.selection() }

            if lock.state == .locked {
                LockScreen(lock: lock, settings: settings)
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    .zIndex(10)
            }
        }
        .environment(lock)
        .task {
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
        .animation(.smooth(duration: 0.25), value: lock.state)
    }
}

enum AppTab: Hashable {
    case dashboard, smoking, water, records, settings
}
