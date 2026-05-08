import SwiftUI
import SwiftData

struct HealthRecoveryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SmokingLog.at, order: .reverse) private var smokes: [SmokingLog]
    @Query private var markers: [UsageMarker]
    @Query private var settingsList: [AppSettings]
    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }
    @State private var tick = 0

    /// "上次吸烟时间"作为恢复起点；若无记录，用 App 启动时间
    private var startAt: Date {
        _ = tick
        if let last = smokes.first {
            return last.at
        }
        return markers.first?.startedAt ?? .now
    }

    private var elapsedSinceStart: TimeInterval {
        Date.now.timeIntervalSince(startAt)
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

    private var lifeExtended: TimeInterval {
        HealthMilestones.lifeExtended(reducedCigs: totalReducedCigs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                milestonesList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("身体恢复")
        .navigationBarTitleDisplayMode(.large)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            tick &+= 1
        }
    }

    private var headerCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("距离上次吸烟")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(formatElapsed(elapsedSinceStart))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            if totalReducedCigs > 0 {
                HStack(spacing: 20) {
                    statColumn(value: "\(totalReducedCigs)", unit: "根", label: "累计少抽", tint: .green)
                    statColumn(value: formatLifeExtended(), unit: "", label: "延长寿命", tint: .pink)
                }
            }
        }
        .padding(22)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func statColumn(value: String, unit: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var milestonesList: some View {
        VStack(spacing: 14) {
            ForEach(HealthMilestones.all) { milestone in
                milestoneRow(milestone)
            }
        }
    }

    private func milestoneRow(_ m: HealthMilestone) -> some View {
        let completed = m.isCompleted(since: startAt)
        let progress = m.progress(since: startAt)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(m.tint.opacity(0.15), lineWidth: 3)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(m.tint.gradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Image(systemName: completed ? "checkmark" : m.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(completed ? m.tint : m.tint.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(m.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(m.durationDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(completed ? .green : .secondary)
                        .monospacedDigit()
                }
                Text(m.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !completed && progress > 0 {
                    ProgressView(value: progress)
                        .tint(m.tint)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .opacity(completed ? 1 : 0.85)
    }

    // MARK: - Formatting

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds)) 秒" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟" }
        if seconds < 86400 { return Fmt.duration(Int(seconds)) }
        let days = Int(seconds / 86400)
        let remaining = Int(seconds.truncatingRemainder(dividingBy: 86400))
        let h = remaining / 3600
        return "\(days) 天 \(h) 小时"
    }

    private func formatLifeExtended() -> String {
        let seconds = lifeExtended
        if seconds < 3600 { return "\(Int(seconds / 60)) 分" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) 小时" }
        return "\(Int(seconds / 86400)) 天"
    }
}
