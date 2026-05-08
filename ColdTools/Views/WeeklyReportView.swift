import SwiftUI
import SwiftData
import Charts

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]
    @Query(sort: \CravingLog.at, order: .reverse) private var cravings: [CravingLog]
    @Query(sort: \WaterLog.at, order: .reverse) private var waters: [WaterLog]
    @Query(sort: \HealthLog.createdAt, order: .reverse) private var healths: [HealthLog]
    @Query private var settingsList: [AppSettings]
    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }

    private var thisWeekKeys: [String] { (-6...0).map { DateKey.day(DateKey.daysAgo($0)) } }
    private var lastWeekKeys: [String] { (-13 ... -7).map { DateKey.day(DateKey.daysAgo($0)) } }

    private var thisWeekSmoke: Int {
        thisWeekKeys.reduce(0) { acc, key in
            acc + smokes.filter { $0.dayKey == key }.count
        }
    }
    private var lastWeekSmoke: Int {
        lastWeekKeys.reduce(0) { acc, key in
            acc + smokes.filter { $0.dayKey == key }.count
        }
    }
    private var thisWeekCraving: Int {
        thisWeekKeys.reduce(0) { acc, key in
            acc + cravings.filter { $0.dayKey == key }.count
        }
    }
    private var thisWeekWater: Int {
        var total = 0
        for key in thisWeekKeys {
            for log in waters where log.dayKey == key {
                total += log.amount
            }
        }
        return total
    }

    private var diff: Int { thisWeekSmoke - lastWeekSmoke }
    private var weekSaved: Double {
        let baselineWeek = settings.baselineCigs * 7
        let saved = max(baselineWeek - thisWeekSmoke, 0)
        return Double(saved) * settings.pricePerStick
    }

    private struct MoodStat: Identifiable {
        let id: Mood
        let avgPerDay: Double
        var mood: Mood { id }
    }

    private var correlation: [MoodStat] {
        var grouped: [Mood: [Int]] = [:]
        for h in healths {
            let day = h.dayKey
            let count = smokes.filter { $0.dayKey == day }.count
            grouped[h.mood, default: []].append(count)
        }
        return Mood.allCases.compactMap { m -> MoodStat? in
            let values = grouped[m] ?? []
            guard !values.isEmpty else { return nil }
            let avg = Double(values.reduce(0, +)) / Double(values.count)
            guard avg > 0 else { return nil }
            return MoodStat(id: m, avgPerDay: avg)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "本周总结") {
                    VStack(spacing: 10) {
                        reportRow(label: "本周吸烟", value: "\(thisWeekSmoke) 根")
                        reportRow(label: "日均", value: String(format: "%.1f 根", Double(thisWeekSmoke) / 7))
                        reportRow(label: "对比上周", value: "\(diff <= 0 ? "↓" : "↑") \(abs(diff))", tint: diff <= 0 ? .green : .red)
                        reportRow(label: "忍住次数", value: "\(thisWeekCraving) 次", tint: .green)
                        reportRow(label: "本周喝水", value: String(format: "%.1f L", Double(thisWeekWater) / 1000))
                        reportRow(label: "本周省下", value: Fmt.money(weekSaved), tint: .green)
                    }
                }

                SectionCard(title: "本周吸烟趋势") {
                    Chart {
                        ForEach(thisWeekKeys, id: \.self) { key in
                            let c = smokes.filter { $0.dayKey == key }.count
                            let date = DateKey.formatter.date(from: key) ?? .now
                            BarMark(
                                x: .value("日期", date, unit: .day),
                                y: .value("根数", c)
                            )
                            .foregroundStyle(.red.opacity(0.7))
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        }
                    }
                    .frame(height: 140)
                }

                SectionCard(title: "心情 vs 吸烟") {
                    if correlation.isEmpty {
                        EmptyStateView(icon: "link.circle", text: "记录健康后查看关联")
                            .padding(.vertical, 16)
                    } else {
                        let maxV = max(correlation.map { $0.avgPerDay }.max() ?? 1, 1)
                        VStack(spacing: 8) {
                            ForEach(correlation) { item in
                                HStack {
                                    Text("\(item.mood.emoji) \(item.mood.rawValue)").font(.subheadline).frame(width: 80, alignment: .leading)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color(.tertiarySystemBackground))
                                            Capsule().fill(Color.accentColor)
                                                .frame(width: geo.size.width * CGFloat(item.avgPerDay / maxV))
                                        }
                                    }
                                    .frame(height: 8)
                                    Text(String(format: "%.1f", item.avgPerDay))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func reportRow(label: String, value: String, tint: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
        }
    }
}
