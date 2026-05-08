import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var unlocked: [UnlockedAchievement]

    private var unlockedCodes: Set<String> {
        Set(unlocked.map(\.code))
    }

    private var groups: [Achievement.Category: [Achievement]] {
        Dictionary(grouping: AchievementCatalog.all, by: \.category)
    }

    private var sortedCategories: [Achievement.Category] {
        Achievement.Category.allCases
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                statsHeader

                ForEach(sortedCategories, id: \.self) { cat in
                    if let items = groups[cat], !items.isEmpty {
                        categorySection(category: cat, items: items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsHeader: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(unlockedCodes.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                Text("已解锁")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("\(AchievementCatalog.all.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("总数")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(progressPercentText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .monospacedDigit()
                Text("完成度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var progressPercentText: String {
        let ratio = Double(unlockedCodes.count) / Double(max(AchievementCatalog.all.count, 1))
        return "\(Int(ratio * 100))%"
    }

    private func categorySection(category: Achievement.Category, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                let unlockedInCat = items.filter { unlockedCodes.contains($0.code) }.count
                Text("\(unlockedInCat)/\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items) { item in
                    AchievementCard(
                        achievement: item,
                        isUnlocked: unlockedCodes.contains(item.code),
                        unlockedAt: unlocked.first(where: { $0.code == item.code })?.unlockedAt
                    )
                }
            }
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let unlockedAt: Date?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.tint.gradient.opacity(1) : Color.gray.opacity(0.15).gradient.opacity(1))
                    .frame(width: 60, height: 60)
                    .shadow(color: isUnlocked ? achievement.tint.opacity(0.4) : .clear, radius: 6, y: 3)
                Image(systemName: achievement.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isUnlocked ? .white : .secondary)
            }

            VStack(spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
                Text(achievement.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }

            if let d = unlockedAt {
                Text(Fmt.dayShort(d))
                    .font(.caption2)
                    .foregroundStyle(achievement.tint)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .opacity(isUnlocked ? 1 : 0.6)
    }
}
