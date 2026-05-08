import Foundation
import SwiftData

@Model
final class WaterLog {
    var id: UUID
    var at: Date
    var amount: Int

    init(id: UUID = UUID(), at: Date = .now, amount: Int = 250) {
        self.id = id
        self.at = at
        self.amount = amount
    }

    var dayKey: String { DateKey.day(at) }
}
