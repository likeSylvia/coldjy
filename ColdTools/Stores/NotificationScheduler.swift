import Foundation
import UserNotifications

enum NotificationScheduler {
    static let iosPendingLimit = 60

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    static func rescheduleWaterReminders(settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        // 取消当前所有水提醒 (id 前缀 water_)
        let pending = await center.pendingNotificationRequests()
        let waterIds = pending.map(\.identifier).filter { $0.hasPrefix("water_") || $0.hasPrefix("quit_") }
        center.removePendingNotificationRequests(withIdentifiers: waterIds)

        guard settings.waterRemindersEnabled else { return }

        let startH = max(0, min(23, settings.waterStartHour))
        let endH = max(startH, min(23, settings.waterEndHour))
        let interval = max(15, settings.waterIntervalMin)

        var slots: [(hour: Int, minute: Int)] = []
        var h = startH
        var m = 0
        while h <= endH {
            slots.append((h, m))
            m += interval
            while m >= 60 { m -= 60; h += 1 }
        }
        // 合理限流
        let waterSlots = Array(slots.prefix(iosPendingLimit - 4))

        for (i, slot) in waterSlots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💧 该喝水了"
            content.body = "补个水，今日目标 \(settings.waterGoalML)ml"
            content.sound = .default

            var comps = DateComponents()
            comps.hour = slot.hour
            comps.minute = slot.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "water_\(i)", content: content, trigger: trigger)
            try? await center.add(request)
        }

        // 戒烟鼓励
        for (i, hour) in [10, 14, 16, 20].enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "🚭 忍一忍"
            content.body = "深呼吸，烟瘾很快就会过去"
            content.sound = .default
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "quit_\(i)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
