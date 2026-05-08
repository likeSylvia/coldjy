import Foundation
import SwiftData

// Convenience to fetch-or-create the single AppSettings row.
enum AppSettingsStore {
    static func current(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = AppSettings()
        context.insert(fresh)
        try? context.save()
        return fresh
    }
}
