import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.modelContext) private var context
    @Environment(LockStore.self) private var lock

    @Query private var settingsList: [AppSettings]
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]
    @Query(sort: \CravingLog.at, order: .reverse) private var cravings: [CravingLog]
    @Query(sort: \WaterLog.at, order: .reverse) private var waters: [WaterLog]
    @Query(sort: \MemoNote.createdAt, order: .reverse) private var notes: [MemoNote]

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

    private var reducedCount: Int { max(settings.baselineCigs - todaySmokes.count, 0) }
    private var savedMoney: Double { Double(reducedCount) * settings.pricePerStick }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timerHero
                    quickActions
                    weekTrendCard
                    todayTimeline
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .background(backgroundGradient)
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
                TriggerPickerSheet { trigger in
                    saveSmoke(trigger: trigger)
                } onCancel: {}
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                tickerTick &+= 1
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Timer Hero

    private var timerHero: some View {
        HStack(spacing: 20) {
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
                    Text("比正常少 \(reducedCount) 根 · 省 \(Fmt.money(savedMoney))")
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
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
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
            .frame(height: 130)
        }
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

    private func saveSmoke(trigger: String) {
        let s = SmokingLog(at: .now, trigger: trigger)
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
