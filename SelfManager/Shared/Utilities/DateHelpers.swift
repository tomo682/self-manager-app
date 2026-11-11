import Foundation

enum DateText {
    /// 例: 11/14(土) 23:59
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day().weekday(.short).hour().minute())
    }

    /// 例: 11/14(土)
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day().weekday(.short))
    }

    /// 例: 2026/11/14
    static func fullDay(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day())
    }

    /// 例: 19:00
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// 例: 11/14(土) 19:00〜20:00
    static func range(_ interval: DateInterval) -> String {
        "\(short(interval.start))〜\(time(interval.end))"
    }
}

enum Weekday {
    static let names = ["日", "月", "火", "水", "木", "金", "土"]

    /// 1=日 … 7=土
    static func name(_ weekday: Int) -> String {
        names[((weekday - 1) % 7 + 7) % 7]
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    /// 0時からの分数
    func minutesFromMidnight(_ date: Date) -> Int {
        let c = dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// その日の0時から minutes 分後
    func date(on day: Date, minutes: Int) -> Date {
        self.date(byAdding: .minute, value: minutes, to: startOfDay(for: day)) ?? day
    }
}
