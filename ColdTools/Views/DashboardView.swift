import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var selectedTab: AppTab
    @Binding var showCraving: Bool
    @Binding var showBreathing: Bool

    @Environment(\.modelContext) private var context
    @Environment(LockStore.self) private var lock
    @Environment(\.colorScheme) private var scheme

    @Query private var settingsList: [AppSettings]
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]
    @Query(sort: \CravingLog.at, order: .reverse) private var cravings: [CravingLog]
    @Query(sort: \WaterLog.at, order: .reverse) private var waters: [WaterLog]
    @Query(sort: \MemoNote.createdAt, order: .reverse) private var notes: [MemoNote]
    @Query private var markers: [UsageMarker]

    @State private var showTrigger = false
    @State private var tickerTick = 0

    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }

    private var todayKey: String { DateKey.day(.now) }
    private var todaySmokes: [SmokingLog] { smokes.filter { $0.dayKey == todayKey } }
    private var todayCravings: [CravingLog] { cravings.filter { $0.dayKey == todayKey } }
    private var todayWaters: [WaterLog] { waters.filter { $0.dayKey == todayKey } }
    private var waterAmountToday: Int { todayWaters.reduce(0) { $0 + $1.amount } }

    private var lastSmokeSeconds: Int? {
        guard let last = smokes.first else { return nil }
        _ = tickerTick
        return max(0, Int(Date.now.timeIntervalSince(last.at)))
    }

    private var reducedTodayCount: Int {
        max(settings.baselineCigs - todaySmokes.count, 0)
    }
    private var savedMoneyToday: Double {
        Double(reducedTodayCount) * settings.pricePerStick
    }

    // 累计指标
    private var totalUsageDays: Int {
        guard let start = markers.first?.startedAt else { return 1 }
        let days = Int(Date.now.timeIntervalSince(start) / 86400) + 1
        return max(1, days)
    }

    private var totalReducedCigs: Int {
        var out = 0
        for offset in -60 ... 0 {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let count = smokes.filter { $0.dayKey == d }.count
            out += max(settings.baselineCigs - count, 0)
        }
        return out
    }

    private var totalSavedMoney: Double {
        Double(totalReducedCigs) * settings.pricePerStick
    }

    private var currentStreak: Int {
        let target = settings.targetCigs
        var streak = 0
        for offset in stride(from: 0, through: -60, by: -1) {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let count = smokes.filter { $0.dayKey == d }.count
            if offset == 0 && count == 0 && smokes.isEmpty { continue }
            if count <= target { streak += 1 } else { break }
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    timerHero
                    panicButtons
                    quickActions
                    MilestonesCard(
                        totalDays: totalUsageDays,
                        reducedCigs: totalReducedCigs,
                        savedMoney: totalSavedMoney,
                        currentStreak: currentStreak
                    )
                    weekTrendCard
                    todayTimeline
                    shortcutLinks
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        lock.lockNow(settings: settings)
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                    .disabled(settings.lockMode == .off)
                }
            }
            .sheet(isPresented: $showTrigger) {
                TriggerPickerSheet(context: context) { trigger, date in
                    saveSmoke(trigger: trigger, at: date)
                } onCancel: {}
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                tickerTick &+= 1
            }
        }
    }

    // MARK: - Timer Hero

    private var timerHero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("距上次吸烟")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(lastSmokeSeconds.map { Fmt.duration($0) } ?? "还没抽过")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText())
                Label {
                    Text("少 \(reducedTodayCount) 根 · 省 \(Fmt.money(savedMoneyToday))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            Spacer()
            ProgressRing(
                value: settings.targetCigs > 0 ? min(Double(todaySmokes.count) / Double(settings.targetCigs), 1) : 0,
                label: "\(todaySmokes.count)/\(settings.targetCigs)"
            )
        }
        .padding(22)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 3)
    }

    // MARK: - Panic Buttons

    private var panicButtons: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap(.medium)
                showCraving = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("烟瘾来了")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background {
                    Capsule().fill(Color.orange.gradient)
                        .shadow(color: .orange.opacity(0.3), radius: 6, y: 2)
                }
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                showBreathing = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                    Text("深呼吸")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.primary)
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickActionCard(icon: "nosign", tint: .red,
                            title: "记录一根", subtitle: "今日 \(todaySmokes.count) 根") {
                showTrigger = true
            }
            QuickActionCard(icon: "hand.raised.fill", tint: .orange,
                            title: "忍住一次", subtitle: "烟瘾 \(todayCravings.count) 次") {
                logCraving()
            }
            QuickActionCard(icon: "drop.fill", tint: .blue,
                            title: "喝水 250ml", subtitle: "\(waterAmountToday) / \(settings.waterGoalML)ml") {
                logWater(amount: 250)
            }
            QuickActionCard(icon: "square.and.pencil", tint: .purple,
                            title: "写备忘", subtitle: "\(notes.filter { !$0.done }.count) 条待办") {
                selectedTab = .records
            }
        }
    }

    // MARK: - Week Trend

    private struct DayCount: Identifiable {
        let id: String
        let date: Date
        let count: Int
    }

    private var weekChartData: [DayCount] {
        (-6...0).map { offset in
            let d = DateKey.daysAgo(offset)
            let key = DateKey.day(d)
            let count = smokes.filter { $0.dayKey == key }.count
            return DayCount(id: key, date: d, count: count)
        }
    }

    private var weekTrendCard: some View {
        SectionCard(title: "7 天趋势") {
            Chart {
                ForEach(weekChartData) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("根数", item.count),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(
                        Calendar.current.isDateInToday(item.date)
                            ? Color.accentColor.gradient
                            : Color.accentColor.opacity(0.35).gradient
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                RuleMark(y: .value("目标", settings.targetCigs))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("目标 \(settings.targetCigs)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .font(.caption.weight(.medium))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 140)
        }
    }

    // MARK: - Shortcut links

    private var shortcutLinks: some View {
        VStack(spacing: 10) {
            NavigationLink {
                HealthRecoveryView()
            } label: {
                shortcutRow(icon: "heart.text.square.fill", tint: .pink, title: "身体恢复时间线", desc: "看身体一点点变好")
            }
            NavigationLink {
                AchievementsView()
            } label: {
                shortcutRow(icon: "trophy.fill", tint: .orange, title: "成就徽章", desc: "解锁里程碑")
            }
            NavigationLink {
                TriggerHeatmapView()
            } label: {
                shortcutRow(icon: "flame.fill", tint: .red, title: "诱因热图", desc: "看什么时候最容易想抽")
            }
        }
    }

    private func shortcutRow(icon: String, tint: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.gradient.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    // MARK: - Timeline

    private var todayTimeline: some View {
        SectionCard(title: "今日动态") {
            let items = buildTodayTimeline()
            if items.isEmpty {
                EmptyStateView(icon: "tray", text: "今天还没有记录")
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        TimelineRow(item: item) { id in
                            deleteItem(id: id, kind: item.kind)
                        }
                        if item.id != items.last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    fileprivate struct TimelineItem: Identifiable {
        enum Kind { case smoke, craving, water }
        let id: UUID
        let kind: Kind
        let title: String
        let at: Date
        let tint: Color
        let icon: String
    }

    private func buildTodayTimeline() -> [TimelineItem] {
        var items: [TimelineItem] = []
        for s in todaySmokes {
            items.append(.init(id: s.id, kind: .smoke,
                               title: "吸烟 · \(s.trigger.isEmpty ? "未标记" : s.trigger)",
                               at: s.at, tint: .red, icon: "nosign"))
        }
        for c in todayCravings {
            items.append(.init(id: c.id, kind: .craving,
                               title: "忍住一次烟瘾",
                               at: c.at, tint: .orange, icon: "hand.raised.fill"))
        }
        for w in todayWaters {
            items.append(.init(id: w.id, kind: .water,
                               title: "喝水 \(w.amount)ml",
                               at: w.at, tint: .blue, icon: "drop.fill"))
        }
        return items.sorted { $0.at > $1.at }.prefix(8).map { $0 }
    }

    // MARK: - Actions

    private func saveSmoke(trigger: String, at date: Date) {
        let s = SmokingLog(at: date, trigger: trigger)
        context.insert(s)
        try? context.save()
        Haptics.warning()
    }

    private func logCraving() {
        let c = CravingLog(at: .now, resisted: true)
        context.insert(c)
        try? context.save()
        Haptics.success()
    }

    private func logWater(amount: Int) {
        let w = WaterLog(at: .now, amount: amount)
        context.insert(w)
        try? context.save()
        Haptics.tap(.soft)
    }

    private func deleteItem(id: UUID, kind: TimelineItem.Kind) {
        switch kind {
        case .smoke:
            if let target = smokes.first(where: { $0.id == id }) { context.delete(target) }
        case .craving:
            if let target = cravings.first(where: { $0.id == id }) { context.delete(target) }
        case .water:
            if let target = waters.first(where: { $0.id == id }) { context.delete(target) }
        }
        try? context.save()
        Haptics.tap()
    }
}

// MARK: - Private TimelineRow

private struct TimelineRow: View {
    let item: DashboardView.TimelineItem
    let onDelete: (UUID) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.tint.gradient.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                Text(Fmt.timeOfDay(item.at))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(item.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
