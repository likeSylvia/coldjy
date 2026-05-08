import Foundation
import SwiftData

enum WorkStatus: String, CaseIterable, Identifiable, Codable {
    case normal = "正常"
    case overtime = "加班"
    case rest = "休息"
    case leave = "请假"
    case late = "迟到"

    var id: String { rawValue }
}

@Model
final class WorkLog {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var startAt: Date?
    var endAt: Date?
    var statusRaw: String = "正常"
    var hours: Double?
    var note: String = ""

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         startAt: Date? = nil,
         endAt: Date? = nil,
         status: WorkStatus = .normal,
         hours: Double? = nil,
         note: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.startAt = startAt
        self.endAt = endAt
        self.statusRaw = status.rawValue
        self.hours = hours
        self.note = note
    }

    var status: WorkStatus { WorkStatus(rawValue: statusRaw) ?? .normal }
    var dayKey: String { DateKey.day(createdAt) }
}
