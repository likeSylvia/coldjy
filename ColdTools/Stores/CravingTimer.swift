import Foundation
import Observation
import ActivityKit

@Observable
final class CravingTimer {
    enum State {
        case idle
        case running(start: Date)
        case finished(duration: TimeInterval)
    }

    private(set) var state: State = .idle
    private(set) var tick: Int = 0
    private var timer: Timer?
    private var activity: Activity<CravingAttributes>?

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
        let now = Date.now
        state = .running(start: now)
        tick = 0
        Haptics.tap(.medium)

        // 启动灵动岛
        startLiveActivity(startDate: now)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick &+= 1
            guard let self else { return }
            if case .running(let s) = self.state {
                let elapsed = Date.now.timeIntervalSince(s)
                if elapsed >= self.targetDuration && elapsed < self.targetDuration + 1 {
                    Haptics.success()
                }
            }
        }
    }

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
        endLiveActivity(resisted: true)
        return duration
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        state = .idle
        Haptics.tap(.light)
        endLiveActivity(resisted: false)
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        endLiveActivity(resisted: false)
    }

    // MARK: - Live Activity

    private func startLiveActivity(startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = CravingAttributes(title: "烟瘾计时")
        let content = ActivityContent(
            state: CravingAttributes.ContentState(
                startDate: startDate,
                targetSeconds: Int(targetDuration),
                resisted: false
            ),
            staleDate: startDate.addingTimeInterval(targetDuration + 60)
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("[CravingTimer] live activity start failed: \(error)")
        }
    }

    private func endLiveActivity(resisted: Bool) {
        guard let activity else { return }
        Task {
            let finalContent = ActivityContent(
                state: CravingAttributes.ContentState(
                    startDate: activity.content.state.startDate,
                    targetSeconds: activity.content.state.targetSeconds,
                    resisted: resisted
                ),
                staleDate: nil
            )
            await activity.end(finalContent, dismissalPolicy: .after(Date.now.addingTimeInterval(2)))
        }
        self.activity = nil
    }
}
