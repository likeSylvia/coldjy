import SwiftUI
import SwiftData

struct TriggerHeatmapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]

    /// 7x24 热力矩阵（周一到周日 × 0-23 小时）
    private var heatmap: [[Int]] {
        var matrix: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        let cal = Calendar(identifier: .gregorian)
        // 只统计最近 30 天
        let cutoff = DateKey.daysAgo(-29)
        for s in smokes where s.at >= cutoff {
            let weekday = (cal.component(.weekday, from: s.at) + 5) % 7   // 1=Sun→6, 2=Mon→0 ... 7=Sat→5
            let hour = cal.component(.hour, from: s.at)
            matrix[weekday][hour] += 1
        }
        return matrix
    }

    private var maxCell: Int {
        heatmap.flatMap { $0 }.max() ?? 1
    }

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heatmapCard
                triggerBreakdown
                topMomentsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("诱因热图")
        .navigationBarTitleDisplayMode(.large)
    }

    private var heatmapCard: some View {
        SectionCard(title: "近 30 天时段热图") {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    // 时刻列表头
                    HStack(spacing: 3) {
                        Text("")
                            .frame(width: 20)
                        ForEach(0..<24, id: \.self) { h in
                            Text(h % 6 == 0 ? "\(h)" : "")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)
                        }
                    }
                    ForEach(0..<7, id: \.self) { day in
                        HStack(spacing: 3) {
                            Text(weekdays[day])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            ForEach(0..<24, id: \.self) { hour in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(value: heatmap[day][hour]))
                                    .frame(width: 12, height: 16)
                            }
                        }
                    }

                    // 图例
                    HStack(spacing: 6) {
                        Text("少")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(0..<5, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(Double(level) * 0.2 + 0.1))
                                .frame(width: 12, height: 12)
                        }
                        Text("多")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func cellColor(value: Int) -> Color {
        if value == 0 { return Color.secondary.opacity(0.08) }
        let intensity = Double(value) / Double(max(maxCell, 1))
        return Color.red.opacity(0.15 + intensity * 0.65)
    }

    // MARK: - Trigger breakdown

    private var triggerCounts: [(String, Int)] {
        let cutoff = DateKey.daysAgo(-29)
        let filtered = smokes.filter { $0.at >= cutoff && !$0.trigger.isEmpty }
        let dict = Dictionary(grouping: filtered, by: \.trigger).mapValues { $0.count }
        return dict.sorted { $0.value > $1.value }
    }

    private var triggerBreakdown: some View {
        SectionCard(title: "30 天诱因分布") {
            if triggerCounts.isEmpty {
                EmptyStateView(icon: "chart.pie", text: "没有带诱因的记录")
                    .padding(.vertical, 16)
            } else {
                let total = triggerCounts.reduce(0) { $0 + $1.1 }
                VStack(spacing: 10) {
                    ForEach(triggerCounts, id: \.0) { trigger, count in
                        HStack {
                            Text(trigger).font(.subheadline)
                                .frame(width: 60, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.red.opacity(0.1))
                                    Capsule().fill(Color.red.gradient)
                                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(total, 1)))
                                }
                            }
                            .frame(height: 10)
                            Text("\(Int(Double(count) / Double(total) * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top moments

    private var topMomentsCard: some View {
        let top = heatmap.enumerated().flatMap { d, row in
            row.enumerated().map { h, v in (day: d, hour: h, count: v) }
        }.sorted { $0.count > $1.count }.prefix(5).filter { $0.count > 0 }

        return SectionCard(title: "最常吸烟的时刻") {
            if top.isEmpty {
                EmptyStateView(icon: "calendar", text: "数据积累后这里会显示")
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(top.enumerated()), id: \.offset) { idx, item in
                        HStack {
                            Text("#\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                                .frame(width: 28)
                            Text("周\(weekdays[item.day]) \(item.hour):00 - \(item.hour + 1):00")
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count) 次")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
