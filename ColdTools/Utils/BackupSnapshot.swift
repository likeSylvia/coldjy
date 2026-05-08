import Foundation

struct BackupSnapshot: Codable {
    struct SmokeRow: Codable {
        let id: UUID
        let at: Date
        let trigger: String
        let note: String
        init(id: UUID, at: Date, trigger: String, note: String) {
            self.id = id; self.at = at; self.trigger = trigger; self.note = note
        }
        init(_ log: SmokingLog) {
            self.id = log.id; self.at = log.at; self.trigger = log.trigger; self.note = log.note
        }
    }

    struct CravingRow: Codable {
        let id: UUID
        let at: Date
        let trigger: String
        let intensity: Int
        let resisted: Bool
        let note: String
        init(_ log: CravingLog) {
            self.id = log.id; self.at = log.at; self.trigger = log.trigger
            self.intensity = log.intensity; self.resisted = log.resisted; self.note = log.note
        }
    }

    struct WaterRow: Codable {
        let id: UUID
        let at: Date
        let amount: Int
        init(_ log: WaterLog) {
            self.id = log.id; self.at = log.at; self.amount = log.amount
        }
    }

    struct HealthRow: Codable {
        let id: UUID
        let createdAt: Date
        let weight: Double?
        let sleepHours: Double?
        let moodRaw: String
        let energyRaw: String
        let bodyNote: String
        init(_ log: HealthLog) {
            self.id = log.id; self.createdAt = log.createdAt
            self.weight = log.weight; self.sleepHours = log.sleepHours
            self.moodRaw = log.moodRaw; self.energyRaw = log.energyRaw
            self.bodyNote = log.bodyNote
        }
    }

    struct WorkRow: Codable {
        let id: UUID
        let createdAt: Date
        let startAt: Date?
        let endAt: Date?
        let statusRaw: String
        let hours: Double?
        let note: String
        init(_ log: WorkLog) {
            self.id = log.id; self.createdAt = log.createdAt
            self.startAt = log.startAt; self.endAt = log.endAt
            self.statusRaw = log.statusRaw; self.hours = log.hours
            self.note = log.note
        }
    }

    struct NoteRow: Codable {
        let id: UUID
        let createdAt: Date
        let title: String
        let content: String
        let tag: String
        let remindAt: Date?
        let pinned: Bool
        let done: Bool
        init(_ note: MemoNote) {
            self.id = note.id; self.createdAt = note.createdAt
            self.title = note.title; self.content = note.content
            self.tag = note.tag; self.remindAt = note.remindAt
            self.pinned = note.pinned; self.done = note.done
        }
    }

    struct SettingsRow: Codable {
        let baselineCigs: Int
        let targetCigs: Int
        let packPrice: Double
        let sticksPerPack: Int
        let waterGoalML: Int
        let waterStartHour: Int
        let waterEndHour: Int
        let waterIntervalMin: Int
        init(from s: AppSettings) {
            self.baselineCigs = s.baselineCigs
            self.targetCigs = s.targetCigs
            self.packPrice = s.packPrice
            self.sticksPerPack = s.sticksPerPack
            self.waterGoalML = s.waterGoalML
            self.waterStartHour = s.waterStartHour
            self.waterEndHour = s.waterEndHour
            self.waterIntervalMin = s.waterIntervalMin
        }
    }

    let smokes: [SmokeRow]
    let cravings: [CravingRow]
    let waters: [WaterRow]
    let healths: [HealthRow]
    let works: [WorkRow]
    let notes: [NoteRow]
    let settings: SettingsRow
}
