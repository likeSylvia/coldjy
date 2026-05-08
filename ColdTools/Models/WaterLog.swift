import Foundation
import SwiftData

@Model
final class WaterLog {
    @Attribute(.unique) var id: UUID = UUID()
    var at: Date = Date.now
    var amount: Int = 250

    init(id: UUID = UUID(), at: Date = .now, amount: Int = 250) {
        self.id = id
        self.at = at
        self.amount = amount
    }

    var dayKey: String { DateKey.day(at) }
}
