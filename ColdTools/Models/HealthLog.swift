import Foundation
import SwiftData

enum Mood: String, CaseIterable, Identifiable, Codable {
    case happy = "开心"
    case calm = "平稳"
    case irritable = "烦躁"
    case low = "低落"
    case anxious = "焦虑"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😌"
        case .irritable: return "😤"
        case .low: return "😔"
        case .anxious: return "😰"
        }
    }
}

enum Energy: String, CaseIterable, Identifiable, Codable {
    case great = "很好"
    case normal = "普通"
    case tired = "疲惫"
    case sleepy = "困"

    var id: String { rawValue }
}

@Model
final class HealthLog {
    var id: UUID
    var createdAt: Date
    var weight: Double?
    var sleepHours: Double?
    var moodRaw: String
    var energyRaw: String
    var bodyNote: String

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         weight: Double? = nil,
         sleepHours: Double? = nil,
         mood: Mood = .calm,
         energy: Energy = .normal,
         bodyNote: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.weight = weight
        self.sleepHours = sleepHours
        self.moodRaw = mood.rawValue
        self.energyRaw = energy.rawValue
        self.bodyNote = bodyNote
    }

    var mood: Mood { Mood(rawValue: moodRaw) ?? .calm }
    var energy: Energy { Energy(rawValue: energyRaw) ?? .normal }
    var dayKey: String { DateKey.day(createdAt) }
}
