import Foundation
import SwiftData

@Model
final class MemoNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var content: String
    var tag: String
    var remindAt: Date?
    var pinned: Bool
    var done: Bool

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         title: String,
         content: String = "",
         tag: String = "",
         remindAt: Date? = nil,
         pinned: Bool = false,
         done: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.content = content
        self.tag = tag
        self.remindAt = remindAt
        self.pinned = pinned
        self.done = done
    }
}
