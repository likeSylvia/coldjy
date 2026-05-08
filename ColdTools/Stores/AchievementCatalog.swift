import Foundation
import SwiftUI

struct Achievement: Identifiable {
    let code: String
    let title: String
    let desc: String
    let icon: String
    let tint: Color
    let category: Category
    let criterion: (AchievementContext) -> Bool

    var id: String { code }

    enum Category: String, CaseIterable {
        case streak = "坚持"
        case savings = "节省"
        case resist = "意志"
        case water = "水润"
        case record = "记录"
    }
}

struct AchievementContext {
    let allSmokes: [SmokingLog]
    let allCravings: [CravingLog]
    let allWaters: [WaterLog]
    let allHealths: [HealthLog]
    let settings: AppSettings

    var currentStreak: Int {
        let target = settings.targetCigs
        var streak = 0
        for offset in stride(from: 0, through: -60, by: -1) {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let count = allSmokes.filter { $0.dayKey == d }.count
            if offset == 0 && count == 0 && allSmokes.isEmpty { continue }
            if count <= target { streak += 1 } else { break }
        }
        return streak
    }

    var totalReducedCigs: Int {
        var out = 0
        for offset in -60 ... 0 {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let count = allSmokes.filter { $0.dayKey == d }.count
            out += max(settings.baselineCigs - count, 0)
        }
        return out
    }

    var totalSavedMoney: Double {
        Double(totalReducedCigs) * settings.pricePerStick
    }

    var waterStreak: Int {
        var streak = 0
        for offset in stride(from: 0, through: -60, by: -1) {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let amount = allWaters.filter { $0.dayKey == d }.reduce(0) { $0 + $1.amount }
            if offset == 0 && amount == 0 { continue }
            if amount >= settings.waterGoalML { streak += 1 } else { break }
        }
        return streak
    }

    var consecutiveLogDays: Int {
        var streak = 0
        for offset in stride(from: 0, through: -60, by: -1) {
            let d = DateKey.day(DateKey.daysAgo(offset))
            let hasAny = allSmokes.contains { $0.dayKey == d }
                || allCravings.contains { $0.dayKey == d }
                || allWaters.contains { $0.dayKey == d }
                || allHealths.contains { $0.dayKey == d }
            if hasAny { streak += 1 } else if offset == 0 { continue } else { break }
        }
        return streak
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        // 坚持类
        .init(code: "streak_1", title: "万事开头难", desc: "坚持一天达标", icon: "sparkles", tint: .yellow, category: .streak) { $0.currentStreak >= 1 },
        .init(code: "streak_3", title: "初见成效", desc: "连续 3 天达标", icon: "flame", tint: .orange, category: .streak) { $0.currentStreak >= 3 },
        .init(code: "streak_7", title: "一周达标", desc: "连续 7 天达标", icon: "flame.fill", tint: .red, category: .streak) { $0.currentStreak >= 7 },
        .init(code: "streak_30", title: "习惯养成", desc: "连续 30 天达标", icon: "calendar.badge.checkmark", tint: .blue, category: .streak) { $0.currentStreak >= 30 },
        .init(code: "streak_100", title: "百日破茧", desc: "连续 100 天达标", icon: "star.fill", tint: .purple, category: .streak) { $0.currentStreak >= 100 },

        // 节省类
        .init(code: "save_50", title: "省下首金", desc: "累计省下 50 元", icon: "dollarsign.circle", tint: .green, category: .savings) { $0.totalSavedMoney >= 50 },
        .init(code: "save_200", title: "小有成就", desc: "累计省下 200 元", icon: "dollarsign.circle.fill", tint: .mint, category: .savings) { $0.totalSavedMoney >= 200 },
        .init(code: "save_500", title: "月省一餐", desc: "累计省下 500 元", icon: "creditcard.fill", tint: .teal, category: .savings) { $0.totalSavedMoney >= 500 },
        .init(code: "save_2000", title: "换个新物", desc: "累计省下 2000 元", icon: "gift.fill", tint: .pink, category: .savings) { $0.totalSavedMoney >= 2000 },

        // 意志类
        .init(code: "resist_1", title: "首次忍耐", desc: "忍住第一次烟瘾", icon: "hand.raised", tint: .orange, category: .resist) { $0.allCravings.count >= 1 },
        .init(code: "resist_10", title: "十次坚守", desc: "累计忍住 10 次", icon: "hand.raised.fill", tint: .red, category: .resist) { $0.allCravings.count >= 10 },
        .init(code: "resist_50", title: "钢铁意志", desc: "累计忍住 50 次", icon: "shield.fill", tint: .blue, category: .resist) { $0.allCravings.count >= 50 },
        .init(code: "resist_100", title: "百折不挠", desc: "累计忍住 100 次", icon: "shield.lefthalf.filled", tint: .indigo, category: .resist) { $0.allCravings.count >= 100 },

        // 水润类
        .init(code: "water_3", title: "水润 3 天", desc: "连续 3 天达标", icon: "drop", tint: .blue, category: .water) { $0.waterStreak >= 3 },
        .init(code: "water_7", title: "水润一周", desc: "连续 7 天达标", icon: "drop.fill", tint: .cyan, category: .water) { $0.waterStreak >= 7 },
        .init(code: "water_30", title: "水源充沛", desc: "连续 30 天达标", icon: "drop.circle.fill", tint: .teal, category: .water) { $0.waterStreak >= 30 },

        // 记录类
        .init(code: "log_7", title: "记录一周", desc: "连续 7 天有记录", icon: "square.and.pencil", tint: .purple, category: .record) { $0.consecutiveLogDays >= 7 },
        .init(code: "log_30", title: "记录一月", desc: "连续 30 天有记录", icon: "pencil.and.list.clipboard", tint: .indigo, category: .record) { $0.consecutiveLogDays >= 30 },
    ]

    static func evaluate(context: AchievementContext, unlockedCodes: Set<String>) -> [Achievement] {
        all.filter { !unlockedCodes.contains($0.code) && $0.criterion(context) }
    }
}
