import Foundation

enum DateKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static func day(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func daysAgo(_ offset: Int, from reference: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: startOfDay(reference)) ?? reference
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}

extension Date {
    var dayKey: String { DateKey.day(self) }
}
