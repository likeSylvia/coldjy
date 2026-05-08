import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme

    @State private var lock = LockStore()
    @State private var theme: ThemeStore?
    @State private var selectedTab: AppTab = .dashboard
    @State private var cravingTimer = CravingTimer()
    @State private var showCravingSheet = false
    @State private var showBreathingSheet = false
    @State private var pendingAchievements: [Achievement] = []
    @AppStorage(DefaultsKey.onboardingCompleted) private var onboardingDone = false

    @Query private var settingsList: [AppSettings]
    @Query private var smokes: [SmokingLog]
    @Query private var cravings: [CravingLog]
    @Query private var waters: [WaterLog]
    @Query private var healths: [HealthLog]
    @Query private var unlocked: [UnlockedAchievement]

    private var settings: AppSettings {
        settingsList.first ?? AppSettingsStore.current(in: context)
    }

    var body: some View {
        ZStack {
            if !onboardingDone {
                OnboardingView(completed: Binding(
                    get: { onboardingDone },
                    set: { onboardingDone = $0 }
                ))
                .transition(.opacity)
            } else if let theme {
                mainTabs(theme: theme)

                // 顶部成就解锁横幅
                if let first = pendingAchievements.first {
                    VStack {
                        AchievementUnlockBanner(achievement: first)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .id(first.code)
                        Spacer()
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(4))
                            if !pendingAchievements.isEmpty {
                                pendingAchievements.removeFirst()
                            }
                        }
                    }
                    .zIndex(5)
                }
            }

            if lock.state == .locked && onboardingDone {
                LockScreen(lock: lock, settings: settings)
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    .zIndex(10)
            }
        }
        .environment(lock)
        .task {
            let current = AppSettingsStore.current(in: context)
            _ = UsageMarkerStore.current(in: context)
            if theme == nil {
                theme = ThemeStore(settings: current)
            }
            lock.evaluateOnLaunch(settings: current)
            if current.waterRemindersEnabled {
                await NotificationScheduler.rescheduleWaterReminders(settings: current)
            }
            evaluateAchievements()
        }
        .onChange(of: scenePhase) { _, new in
            switch new {
            case .background, .inactive:
                lock.markBackgrounded()
            case .active:
                lock.checkReLock(settings: settings)
                evaluateAchievements()
            @unknown default: break
            }
        }
        .onChange(of: smokes.count) { _, _ in evaluateAchievements() }
        .onChange(of: cravings.count) { _, _ in evaluateAchievements() }
        .onChange(of: waters.count) { _, _ in evaluateAchievements() }
        .animation(.smooth(duration: 0.25), value: lock.state)
        .animation(.smooth(duration: 0.3), value: onboardingDone)
    }

    @ViewBuilder
    private func mainTabs(theme: ThemeStore) -> some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house.fill", value: AppTab.dashboard) {
                DashboardView(selectedTab: $selectedTab,
                              showCraving: $showCravingSheet,
                              showBreathing: $showBreathingSheet)
            }
            Tab("戒烟", systemImage: "nosign", value: AppTab.smoking) {
                QuitSmokingView(showCraving: $showCravingSheet)
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
        .tint(theme.tintColor(scheme: scheme))
        .preferredColorScheme(theme.appearance.colorScheme)
        .environment(theme)
        .environment(cravingTimer)
        .sheet(isPresented: $showCravingSheet) {
            CravingTimerSheet(timer: cravingTimer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBreathingSheet) {
            BreathingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func evaluateAchievements() {
        let ctx = AchievementContext(
            allSmokes: smokes,
            allCravings: cravings,
            allWaters: waters,
            allHealths: healths,
            settings: settings
        )
        let unlockedCodes = Set(unlocked.map(\.code))
        let newlyUnlocked = AchievementCatalog.evaluate(context: ctx, unlockedCodes: unlockedCodes)
        guard !newlyUnlocked.isEmpty else { return }
        for ach in newlyUnlocked {
            context.insert(UnlockedAchievement(code: ach.code))
        }
        try? context.save()
        pendingAchievements.append(contentsOf: newlyUnlocked)
    }
}

enum AppTab: Hashable {
    case dashboard, smoking, water, records, settings
}
