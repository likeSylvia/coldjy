import Foundation
import Observation

@Observable
final class CravingTimer {
    enum State {
        case idle
        case running(start: Date)
        case finished(duration: TimeInterval)
    }

    private(set) var state: State = .idle
    private(set) var tick: Int = 0   // 驱动 view 刷新
    private var timer: Timer?

    /// 推荐忍耐时间: 烟瘾通常 3-5 分钟消退,我们设 5 分钟为目标
    let targetDuration: TimeInterval = 5 * 60

    var currentElapsed: TimeInterval {
        _ = tick
        switch state {
        case .running(let start):
            return Date.now.timeIntervalSince(start)
        case .finished(let d):
            return d
        default:
            return 0
        }
    }

    var progress: Double {
        min(currentElapsed / targetDuration, 1.0)
    }

    var isRunning: Bool {
        if case .running = state { return true } else { return false }
    }

    func start() {
        timer?.invalidate()
        state = .running(start: .now)
        tick = 0
        Haptics.tap(.medium)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick &+= 1
            guard let self else { return }
            // 到目标时震一下
            if case .running(let s) = self.state {
                let elapsed = Date.now.timeIntervalSince(s)
                if elapsed >= self.targetDuration && elapsed < self.targetDuration + 1 {
                    Haptics.success()
                }
            }
        }
    }

    /// 用户主动标记"忍住了",返回持续时间
    @discardableResult
    func complete() -> TimeInterval {
        timer?.invalidate()
        timer = nil
        let duration: TimeInterval
        if case .running(let s) = state {
            duration = Date.now.timeIntervalSince(s)
        } else {
            duration = 0
        }
        state = .finished(duration: duration)
        Haptics.success()
        return duration
    }

    /// 用户放弃,不做任何记录
    func cancel() {
        timer?.invalidate()
        timer = nil
        state = .idle
        Haptics.tap(.light)
    }

    /// 回到空闲态（用于 finished 之后展示完成,然后 view 关闭）
    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
    }
}
