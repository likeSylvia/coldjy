import Foundation
import SwiftData

@Model
final class UsageMarker {
    var id: String
    var startedAt: Date

    init(id: String = "primary", startedAt: Date = .now) {
        self.id = id
        self.startedAt = startedAt
    }
}

enum UsageMarkerStore {
    static func current(in ctx: ModelContext) -> UsageMarker {
        let descriptor = FetchDescriptor<UsageMarker>()
        if let existing = try? ctx.fetch(descriptor).first {
            return existing
        }
        let fresh = UsageMarker()
        ctx.insert(fresh)
        try? ctx.save()
        return fresh
    }
}
