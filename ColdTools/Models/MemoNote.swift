import Foundation
import SwiftData

@Model
final class MemoNote {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var title: String = ""
    var content: String = ""
    var tag: String = ""
    var remindAt: Date?
    var pinned: Bool = false
    var done: Bool = false

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
