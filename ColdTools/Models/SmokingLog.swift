import Foundation
import SwiftData

@Model
final class SmokingLog {
    @Attribute(.unique) var id: UUID = UUID()
    var at: Date = Date.now
    var trigger: String = ""
    var note: String = ""

    init(id: UUID = UUID(), at: Date = .now, trigger: String = "", note: String = "") {
        self.id = id
        self.at = at
        self.trigger = trigger
        self.note = note
    }

    var dayKey: String { DateKey.day(at) }
}
