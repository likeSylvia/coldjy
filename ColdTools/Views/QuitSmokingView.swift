import SwiftUI
import SwiftData

struct QuitSmokingView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]
    @Query(sort: \CravingLog.at, order: .reverse) private var cravings: [CravingLog]

    @State private var showTrigger = false

    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }
    private var todayKey: String { DateKey.day(.now) }
    private var todaySmokes: [SmokingLog] { smokes.filter { $0.dayKey == todayKey } }
    private var todayCravings: [CravingLog] { cravings.filter { $0.dayKey == todayKey } }

    private var reducedCount: Int { max(settings.baselineCigs - todaySmokes.count, 0) }
    private var savedMoney: Double { Double(reducedCount) * settings.pricePerStick }

    // 诱因统计: 本周
    private var triggerStats: [(trigger: String, count: Int)] {
        let cutoff = DateKey.daysAgo(-6)
        let map = Dictionary(grouping: smokes.filter { $0.at >= cutoff && !$0.trigger.isEmpty }, by: \.trigger)
            .mapValues { $0.count }
        return map.map { (trigger: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsRow
                    actionRow
                    triggerStatsCard
                    settingsCard
                    timelineCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("戒烟")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTrigger) {
                TriggerPickerSheet { trigger in
                    addSmoke(trigger: trigger)
                } onCancel: {}
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            MetricTile(title: "已抽", value: "\(todaySmokes.count)", subtitle: "目标 \(settings.targetCigs) 根", tint: .red)
            MetricTile(title: "少抽", value: "\(reducedCount)", subtitle: "相比正常", tint: .green)
            MetricTile(title: "省下", value: Fmt.money(savedMoney), subtitle: "\(Fmt.money(settings.pricePerStick))/根", tint: .blue)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                showTrigger = true
            } label: {
                Label("记一根", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

            Button {
                Haptics.success()
                let c = CravingLog(at: .now, resisted: true)
                context.insert(c); try? context.save()
            } label: {
                Label("忍住了", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var triggerStatsCard: some View {
        SectionCard(title: "7 天诱因") {
            if triggerStats.isEmpty {
                EmptyStateView(icon: "chart.bar", text: "记录诱因后这里会显示统计")
                    .padding(.vertical, 8)
            } else {
                let total = max(triggerStats.first?.count ?? 1, 1)
                VStack(spacing: 8) {
                    ForEach(triggerStats.prefix(6), id: \.trigger) { item in
                        HStack {
                            Text(item.trigger).font(.subheadline).frame(width: 56, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(.tertiarySystemBackground))
                                    Capsule().fill(Color.accentColor)
                                        .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(total))
                                }
                            }
                            .frame(height: 8)
                            Text("\(item.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var settingsCard: some View {
        SectionCard(title: "减量设置") {
            VStack(spacing: 12) {
                HStack {
                    Text("每天正常").frame(maxWidth: .infinity, alignment: .leading)
                    Stepper(value: Binding(get: { settings.baselineCigs }, set: { settings.baselineCigs = $0; try? context.save() }), in: 0...80) {
                        Text("\(settings.baselineCigs)").monospacedDigit()
                    }
                }
                HStack {
                    Text("今日目标").frame(maxWidth: .infinity, alignment: .leading)
                    Stepper(value: Binding(get: { settings.targetCigs }, set: { settings.targetCigs = $0; try? context.save() }), in: 0...80) {
                        Text("\(settings.targetCigs)").monospacedDigit()
                    }
                }
                HStack {
                    Text("每包价格").frame(maxWidth: .infinity, alignment: .leading)
                    TextField("25", value: Binding(get: { settings.packPrice }, set: { settings.packPrice = $0; try? context.save() }), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                HStack {
                    Text("每包根数").frame(maxWidth: .infinity, alignment: .leading)
                    Stepper(value: Binding(get: { settings.sticksPerPack }, set: { settings.sticksPerPack = max(1, $0); try? context.save() }), in: 1...30) {
                        Text("\(settings.sticksPerPack)").monospacedDigit()
                    }
                }
            }
            .labelsHidden()
        }
    }

    private var timelineCard: some View {
        SectionCard(title: "今日时间线") {
            let items = mergedToday()
            if items.isEmpty {
                EmptyStateView(icon: "clock", text: "今天还没有记录")
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(items, id: \.id) { item in
                        HStack {
                            Image(systemName: item.icon).foregroundStyle(item.tint).frame(width: 24)
                            Text(item.title).font(.subheadline)
                            Spacer()
                            Text(Fmt.timeOfDay(item.at)).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(item: item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private struct MixedItem: Identifiable {
        enum Kind { case smoke, craving }
        let id: UUID
        let kind: Kind
        let title: String
        let icon: String
        let tint: Color
        let at: Date
    }

    private func mergedToday() -> [MixedItem] {
        var out: [MixedItem] = []
        for s in todaySmokes {
            out.append(.init(id: s.id, kind: .smoke,
                             title: "吸烟 · \(s.trigger.isEmpty ? "未标记" : s.trigger)",
                             icon: "nosign", tint: .red, at: s.at))
        }
        for c in todayCravings {
            out.append(.init(id: c.id, kind: .craving, title: "忍住一次烟瘾",
                             icon: "hand.raised.fill", tint: .orange, at: c.at))
        }
        return out.sorted { $0.at > $1.at }
    }

    private func addSmoke(trigger: String) {
        let s = SmokingLog(at: .now, trigger: trigger)
        context.insert(s); try? context.save()
        Haptics.warning()
    }

    private func delete(item: MixedItem) {
        switch item.kind {
        case .smoke:
            if let t = smokes.first(where: { $0.id == item.id }) { context.delete(t) }
        case .craving:
            if let t = cravings.first(where: { $0.id == item.id }) { context.delete(t) }
        }
        try? context.save(); Haptics.tap()
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}
