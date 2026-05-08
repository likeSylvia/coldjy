import Foundation

struct AlternativeAction: Identifiable, Hashable {
    let id: String
    let title: String
    let desc: String
    let icon: String
    let duration: String
}

enum Alternatives {
    static let all: [AlternativeAction] = [
        .init(id: "water", title: "喝一杯水", desc: "缓慢喝下 250ml", icon: "drop.fill", duration: "1 分钟"),
        .init(id: "walk", title: "走 200 步", desc: "换个环境呼吸新鲜空气", icon: "figure.walk", duration: "2 分钟"),
        .init(id: "pushup", title: "做 10 个俯卧撑", desc: "让血液循环起来", icon: "figure.strengthtraining.traditional", duration: "2 分钟"),
        .init(id: "mint", title: "嚼薄荷糖/口香糖", desc: "让口腔有事情做", icon: "mouth", duration: "5 分钟"),
        .init(id: "breathe", title: "深呼吸 4-7-8", desc: "吸气 4 秒 屏住 7 秒 呼气 8 秒", icon: "wind", duration: "2 分钟"),
        .init(id: "stretch", title: "伸展 1 分钟", desc: "肩颈腰背放松", icon: "figure.flexibility", duration: "1 分钟"),
        .init(id: "call", title: "给朋友发消息", desc: "聊聊别的话题", icon: "bubble.left.and.bubble.right.fill", duration: "2 分钟"),
        .init(id: "music", title: "听一首喜欢的歌", desc: "转移注意力", icon: "music.note", duration: "3 分钟"),
        .init(id: "tea", title: "泡一杯茶", desc: "让手脚有事做", icon: "cup.and.saucer.fill", duration: "5 分钟"),
        .init(id: "clean", title: "整理桌面", desc: "用 2 分钟让环境干净", icon: "sparkles", duration: "2 分钟"),
    ]

    static func random() -> AlternativeAction {
        all.randomElement() ?? all[0]
    }

    static func random(excluding id: String?) -> AlternativeAction {
        let candidates = all.filter { $0.id != id }
        return candidates.randomElement() ?? all[0]
    }
}

// MARK: - 4-7-8 呼吸引导

struct BreathingPhase: Identifiable {
    let id: String
    let title: String
    let duration: Int
    let color: PhaseColor

    enum PhaseColor {
        case blue, green, purple
    }
}

enum BreathingCycle {
    static let phases: [BreathingPhase] = [
        .init(id: "inhale", title: "吸气", duration: 4, color: .blue),
        .init(id: "hold", title: "屏住", duration: 7, color: .purple),
        .init(id: "exhale", title: "呼气", duration: 8, color: .green),
    ]

    static let cyclesDefault = 4
}
