import Foundation

struct WeeklyInsight {
    let summary: String
    let highlights: [String]
    let suggestions: [String]
}

enum WeeklyInsightBuilder {
    static func build(
        smokes: [SmokingLog],
        cravings: [CravingLog],
        waters: [WaterLog],
        healths: [HealthLog],
        settings: AppSettings
    ) -> WeeklyInsight {
        let thisWeekKeys: [String] = (-6 ... 0).map { DateKey.day(DateKey.daysAgo($0)) }
        let lastWeekKeys: [String] = (-13 ... -7).map { DateKey.day(DateKey.daysAgo($0)) }

        let thisSmoke = thisWeekKeys.reduce(0) { $0 + smokes.filter { s in s.dayKey == $1 }.count }
        let lastSmoke = lastWeekKeys.reduce(0) { $0 + smokes.filter { s in s.dayKey == $1 }.count }
        let thisResist = thisWeekKeys.reduce(0) { $0 + cravings.filter { c in c.dayKey == $1 }.count }
        let waterTotal = thisWeekKeys.reduce(0) { sum, key in
            sum + waters.filter { $0.dayKey == key }.reduce(0) { $0 + $1.amount }
        }
        let waterDaysOnTarget = thisWeekKeys.filter { key in
            waters.filter { $0.dayKey == key }.reduce(0) { $0 + $1.amount } >= settings.waterGoalML
        }.count

        let avgDaily = Double(thisSmoke) / 7.0
        let diff = thisSmoke - lastSmoke

        // 最常见诱因
        let triggerCounts = Dictionary(grouping: smokes.filter {
            thisWeekKeys.contains($0.dayKey) && !$0.trigger.isEmpty
        }, by: \.trigger).mapValues { $0.count }
        let topTrigger = triggerCounts.max { $0.value < $1.value }?.key

        // 心情关联
        var moodSmokeMap: [Mood: [Int]] = [:]
        for h in healths where thisWeekKeys.contains(h.dayKey) {
            let c = smokes.filter { $0.dayKey == h.dayKey }.count
            moodSmokeMap[h.mood, default: []].append(c)
        }
        let worstMood: Mood? = moodSmokeMap.mapValues { vals in
            vals.isEmpty ? 0 : Double(vals.reduce(0, +)) / Double(vals.count)
        }.max { $0.value < $1.value }?.key

        // 组装总结
        var summary: String
        if lastSmoke == 0 && thisSmoke == 0 {
            summary = "这周没有吸烟记录，继续保持！"
        } else if diff < 0 {
            summary = "本周吸烟 \(thisSmoke) 根，比上周少 \(abs(diff)) 根，表现很棒。"
        } else if diff == 0 && lastSmoke > 0 {
            summary = "本周吸烟 \(thisSmoke) 根，与上周持平，可以挑战再少一点。"
        } else if lastSmoke == 0 {
            summary = "本周共记录 \(thisSmoke) 根，日均 \(String(format: "%.1f", avgDaily)) 根。"
        } else {
            summary = "本周吸烟 \(thisSmoke) 根，比上周多 \(diff) 根，留意下压力和情绪。"
        }

        // 关键亮点
        var highlights: [String] = []
        if thisResist > 0 {
            highlights.append("忍住烟瘾 \(thisResist) 次")
        }
        if thisSmoke < settings.baselineCigs * 7 {
            let reduced = settings.baselineCigs * 7 - thisSmoke
            let saved = Double(reduced) * settings.pricePerStick
            highlights.append("少抽 \(reduced) 根，省下 \(Fmt.money(saved))")
        }
        if waterDaysOnTarget > 0 {
            highlights.append("喝水达标 \(waterDaysOnTarget) 天（共 \(waterTotal / 1000).\(abs(waterTotal / 100 % 10))L）")
        }
        if let t = topTrigger {
            highlights.append("最常见诱因：\(t)")
        }

        // 建议
        var suggestions: [String] = []
        if let t = topTrigger {
            switch t {
            case "饭后":
                suggestions.append("饭后立刻刷牙或嚼薄荷糖，打断条件反射")
            case "压力":
                suggestions.append("压力大时试试 4-7-8 深呼吸，App 里有引导")
            case "无聊":
                suggestions.append("烟瘾来时起身走 100 步，换个环境")
            case "社交":
                suggestions.append("提前告诉朋友你在戒烟，减少社交压力")
            case "习惯":
                suggestions.append("改变常抽地点和时段，打破习惯性条件反射")
            case "情绪":
                suggestions.append("情绪波动时抽烟只会加重焦虑，试着记录心情")
            case "提神":
                suggestions.append("喝杯水或伸展 1 分钟，效果比香烟更持久")
            default: break
            }
        }
        if let mood = worstMood, moodSmokeMap[mood]?.count ?? 0 >= 2 {
            suggestions.append("「\(mood.rawValue)」的日子你抽得更多，留意这种心情")
        }
        if thisResist == 0 && thisSmoke > 0 {
            suggestions.append("每次想抽时点「忍住一次」，慢慢积累就是力量")
        }
        if waterDaysOnTarget < 3 {
            suggestions.append("多喝水有助于加速尼古丁代谢")
        }
        if suggestions.isEmpty {
            suggestions.append("继续保持，你做得很好")
        }

        return WeeklyInsight(summary: summary, highlights: highlights, suggestions: suggestions)
    }
}
