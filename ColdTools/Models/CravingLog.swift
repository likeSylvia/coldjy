import Foundation
import SwiftData

@Model
final class CravingLog {
    var id: UUID = UUID()
    var at: Date = Date.now
    var trigger: String = ""
    var intensity: Int = 3
    var resisted: Bool = true
    var note: String = ""

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
