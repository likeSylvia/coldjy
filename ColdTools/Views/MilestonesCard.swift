import SwiftUI

/// 首页的里程碑卡片（天数 / 省钱 / 连击 / 少抽）
struct MilestonesCard: View {
    let totalDays: Int
    let reducedCigs: Int
    let savedMoney: Double
    let currentStreak: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("累计成就", systemImage: "trophy.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
            }

            HStack(spacing: 10) {
                stat(icon: "calendar", tint: .blue,
                     value: "\(totalDays)", unit: "天", label: "使用天数")
                stat(icon: "flame.fill", tint: .red,
                     value: "\(currentStreak)", unit: "天", label: "连续达标")
            }
            HStack(spacing: 10) {
                stat(icon: "leaf.fill", tint: .green,
                     value: "\(reducedCigs)", unit: "根", label: "累计少抽")
                stat(icon: "yensign.circle.fill", tint: .purple,
                     value: Fmt.money(savedMoney), unit: "", label: "累计省下")
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func stat(icon: String, tint: Color, value: String, unit: String, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.gradient.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !unit.isEmpty {
                        Text(unit).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(0.06))
        }
    }
}
