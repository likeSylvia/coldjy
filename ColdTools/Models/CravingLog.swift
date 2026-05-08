import Foundation
import SwiftData

@Model
final class CravingLog {
    @Attribute(.unique) var id: UUID
    var at: Date
    var trigger: String
    var intensity: Int
    var resisted: Bool
    var note: String

    init(id: UUID = UUID(),
         at: Date = .now,
         trigger: String = "",
         intensity: Int = 3,
         resisted: Bool = true,
         note: String = "") {
        self.id = id
        self.at = at
        self.trigger = trigger
        self.intensity = intensity
        self.resisted = resisted
        self.note = note
    }

    var dayKey: String { DateKey.day(at) }
}
