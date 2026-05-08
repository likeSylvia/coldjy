import Foundation
import SwiftData

/// 用户第一次使用 App 的时间
@Model
final class UsageMarker {
    var id: String = "primary"
    var startedAt: Date = Date.now

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
