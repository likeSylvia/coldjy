import Foundation
import SwiftUI

/// 基于 WHO 和 CDC 公开的戒烟后身体恢复数据
struct HealthMilestone: Identifiable {
    let id: String
    let duration: TimeInterval   // 相对"开始时间"的秒数
    let title: String
    let desc: String
    let icon: String
    let tint: Color

    var durationDescription: String {
        let hours = duration / 3600
        let days = duration / 86400
        if hours < 24 { return "\(Int(hours)) 小时" }
        if days < 30 { return "\(Int(days)) 天" }
        if days < 365 { return "\(Int(days / 30)) 个月" }
        return "\(Int(days / 365)) 年"
    }

    /// 进度百分比（0...1）
    func progress(since start: Date) -> Double {
        let elapsed = Date.now.timeIntervalSince(start)
        return max(0, min(1, elapsed / duration))
    }

    func isCompleted(since start: Date) -> Bool {
        Date.now.timeIntervalSince(start) >= duration
    }

    func timeRemaining(since start: Date) -> TimeInterval {
        max(0, duration - Date.now.timeIntervalSince(start))
    }
}

enum HealthMilestones {
    static let all: [HealthMilestone] = [
        .init(
            id: "heartRate",
            duration: 20 * 60,
            title: "心率血压回归正常",
            desc: "尼古丁引起的血管收缩开始缓解",
            icon: "heart.fill",
            tint: .red
        ),
        .init(
            id: "co",
            duration: 12 * 3600,
            title: "血液一氧化碳水平正常",
            desc: "氧气输送能力恢复",
            icon: "lungs.fill",
            tint: .blue
        ),
        .init(
            id: "nicotine",
            duration: 48 * 3600,
            title: "尼古丁完全排出",
            desc: "味觉嗅觉开始敏锐",
            icon: "drop.triangle.fill",
            tint: .cyan
        ),
        .init(
            id: "circulation",
            duration: 14 * 86400,
            title: "血液循环改善",
            desc: "肺功能提升 30%",
            icon: "figure.walk",
            tint: .mint
        ),
        .init(
            id: "coughing",
            duration: 90 * 86400,
            title: "咳嗽和气短明显减少",
            desc: "肺部纤毛重新生长",
            icon: "wind",
            tint: .teal
        ),
        .init(
            id: "heart",
            duration: 365 * 86400,
            title: "心脏病风险减半",
            desc: "显著长期获益",
            icon: "heart.circle.fill",
            tint: .pink
        ),
        .init(
            id: "stroke",
            duration: 5 * 365 * 86400,
            title: "中风风险接近非吸烟者",
            desc: "血管健康大幅恢复",
            icon: "brain.head.profile",
            tint: .purple
        ),
        .init(
            id: "lungCancer",
            duration: 10 * 365 * 86400,
            title: "肺癌风险降低一半",
            desc: "显著降低主要癌症风险",
            icon: "cross.case.fill",
            tint: .green
        ),
    ]

    /// 根据每根烟减寿 11 分钟的 BMJ 研究估算（Shaw et al., 2000）
    static func lifeExtended(reducedCigs: Int) -> TimeInterval {
        Double(reducedCigs) * 11 * 60
    }
}
