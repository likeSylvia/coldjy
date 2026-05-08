import SwiftUI
import SwiftData
import Charts

struct WaterView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]
    @Query(sort: \WaterLog.at, order: .reverse) private var waters: [WaterLog]

    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }
    private var todayKey: String { DateKey.day(.now) }
    private var todayWaters: [WaterLog] { waters.filter { $0.dayKey == todayKey } }
    private var todayAmount: Int { todayWaters.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    quickAmounts
                    weekChart
                    goalSettings
                    timelineCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("喝水")
            .navigationBarTitleDisplayMode(.large)
            .keyboardDoneToolbar()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(todayAmount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                Text("ml")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("目标 \(settings.waterGoalML)ml")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(todayAmount), total: Double(max(settings.waterGoalML, 1)))
                .tint(.blue)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var quickAmounts: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach([100, 250, 500, 750], id: \.self) { amount in
                Button {
                    Haptics.tap(.soft)
                    context.insert(WaterLog(at: .now, amount: amount))
                    try? context.save()
                } label: {
                    Text("\(amount)ml")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.blue)
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.1)))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private struct DayAmount: Identifiable {
        let id: String
        let date: Date
        let amount: Int
    }

    private var weekChart: some View {
        SectionCard(title: "7 天喝水") {
            let data: [DayAmount] = (-6...0).map { offset in
                let d = DateKey.daysAgo(offset)
                let key = DateKey.day(d)
                let amt = waters.filter { $0.dayKey == key }.reduce(0) { $0 + $1.amount }
                return DayAmount(id: key, date: d, amount: amt)
            }
            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("毫升", item.amount)
                    )
                    .foregroundStyle(item.amount >= settings.waterGoalML ? Color.green : Color.blue.opacity(0.6))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("目标", settings.waterGoalML))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .frame(height: 120)
        }
    }

    private var goalSettings: some View {
        SectionCard(title: "目标与提醒") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("每日目标")
                        .font(.subheadline)
                    Spacer()
                    TextField("2000", value: Binding(
                        get: { settings.waterGoalML },
                        set: { settings.waterGoalML = max(0, $0); try? context.save() }
                    ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                        .frame(maxWidth: 100)
                    Text("ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.vertical, 10)

                HStack(spacing: 12) {
                    Text("提醒时段")
                        .font(.subheadline)
                    Spacer()
                    Text("\(settings.waterStartHour):00")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                    Stepper("", value: Binding(
                        get: { settings.waterStartHour },
                        set: {
                            settings.waterStartHour = max(0, min(23, $0))
                            try? context.save()
                            Task { await NotificationScheduler.rescheduleWaterReminders(settings: settings) }
                        }
                    ), in: 0...23)
                        .labelsHidden()
                        .fixedSize()
                    Text("—")
                        .foregroundStyle(.secondary)
                    Text("\(settings.waterEndHour):00")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                    Stepper("", value: Binding(
                        get: { settings.waterEndHour },
                        set: {
                            settings.waterEndHour = max(settings.waterStartHour, min(23, $0))
                            try? context.save()
                            Task { await NotificationScheduler.rescheduleWaterReminders(settings: settings) }
                        }
                    ), in: 0...23)
                        .labelsHidden()
                        .fixedSize()
                }

                Divider().padding(.vertical, 10)

                HStack(spacing: 12) {
                    Text("间隔")
                        .font(.subheadline)
                    Spacer()
                    Text("\(settings.waterIntervalMin)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: settings.waterIntervalMin)
                    Text("分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("", value: Binding(
                        get: { settings.waterIntervalMin },
                        set: {
                            settings.waterIntervalMin = max(15, $0)
                            try? context.save()
                            Task { await NotificationScheduler.rescheduleWaterReminders(settings: settings) }
                        }
                    ), in: 15...180, step: 15)
                        .labelsHidden()
                        .fixedSize()
                }

                Divider().padding(.vertical, 10)

                Toggle("开启系统通知提醒", isOn: Binding(
                    get: { settings.waterRemindersEnabled },
                    set: { newValue in
                        Task {
                            if newValue {
                                let granted = await NotificationScheduler.requestAuthorization()
                                await MainActor.run {
                                    settings.waterRemindersEnabled = granted
                                    try? context.save()
                                }
                                if granted {
                                    await NotificationScheduler.rescheduleWaterReminders(settings: settings)
                                }
                            } else {
                                settings.waterRemindersEnabled = false
                                try? context.save()
                                await NotificationScheduler.rescheduleWaterReminders(settings: settings)
                            }
                        }
                    }
                ))
                .tint(.blue)
            }
        }
    }

    private var timelineCard: some View {
        SectionCard(title: "今日记录") {
            if todayWaters.isEmpty {
                EmptyStateView(icon: "drop", text: "今天还没喝过水")
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(todayWaters, id: \.id) { w in
                        SwipeToDeleteRow(
                            onDelete: {
                                context.delete(w); try? context.save(); Haptics.tap()
                            }
                        ) {
                            HStack {
                                Image(systemName: "drop.fill").foregroundStyle(.blue).frame(width: 24)
                                Text("\(w.amount)ml").font(.subheadline)
                                Spacer()
                                Text(Fmt.timeOfDay(w.at)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                            .padding(.vertical, 10)
                        }
                        if w.id != todayWaters.last?.id { Divider().opacity(0.5) }
                    }
                }
            }
        }
    }
}
