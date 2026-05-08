import Foundation
import ActivityKit

public struct CravingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startDate: Date
        public var targetSeconds: Int
        public var resisted: Bool

        public init(startDate: Date, targetSeconds: Int, resisted: Bool) {
            self.startDate = startDate
            self.targetSeconds = targetSeconds
            self.resisted = resisted
        }
    }

    public var title: String

    public init(title: String = "烟瘾计时") {
        self.title = title
    }
}
