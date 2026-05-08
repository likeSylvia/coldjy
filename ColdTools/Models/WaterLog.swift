import Foundation
import SwiftData

@Model
final class WaterLog {
    @Attribute(.unique) var id: UUID
    var at: Date
    var amount: Int // ml

    init(id: UUID = UUID(), at: Date = .now, amount: Int = 250) {
        self.id = id
        self.at = at
        self.amount = amount
    }

    var dayKey: String { DateKey.day(at) }
}
