import Foundation

/// 習慣的な予定（学校・睡眠など）のルール
struct HabitRule: Equatable {
    /// 1=日 … 7=土
    var weekdays: Set<Int>
    var startMinutes: Int
    /// startMinutes 以下なら翌日の時刻
    var endMinutes: Int
    var validFrom: Date?
    var validTo: Date?
    var exceptionDates: [Date]
}

extension HabitSchedule {
    var rule: HabitRule {
        HabitRule(weekdays: Set(weekdays), startMinutes: startMinutes, endMinutes: endMinutes,
                  validFrom: validFrom, validTo: validTo, exceptionDates: exceptionDates)
    }
}

enum SlotFinder {
    static let step: TimeInterval = 15 * 60

    /// 習慣ルールを、指定期間内の「埋まっている時間」に展開する
    static func habitIntervals(_ rules: [HabitRule], from: Date, to: Date,
                               calendar: Calendar = .current) -> [DateInterval] {
        guard to > from else { return [] }
        var result: [DateInterval] = []
        // 前日から始まって日をまたぐ枠（睡眠など）も拾うため、1日前から見る
        guard var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: from)) else { return [] }
        while day < to {
            let weekday = calendar.component(.weekday, from: day)
            for rule in rules where rule.weekdays.contains(weekday) && isValid(rule, on: day, calendar: calendar) {
                guard rule.startMinutes != rule.endMinutes else { continue }
                let start = calendar.date(on: day, minutes: rule.startMinutes)
                let endDay = rule.endMinutes > rule.startMinutes
                    ? day
                    : (calendar.date(byAdding: .day, value: 1, to: day) ?? day)
                let end = calendar.date(on: endDay, minutes: rule.endMinutes)
                if end > start && end > from && start < to {
                    result.append(DateInterval(start: start, end: end))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    static func isValid(_ rule: HabitRule, on day: Date, calendar: Calendar) -> Bool {
        let d = calendar.startOfDay(for: day)
        if let from = rule.validFrom, d < calendar.startOfDay(for: from) { return false }
        if let to = rule.validTo, d > calendar.startOfDay(for: to) { return false }
        if rule.exceptionDates.contains(where: { calendar.isDate($0, inSameDayAs: d) }) { return false }
        return true
    }

    /// 空き時間を、別々の日から早い順に最大 count 個返す
    ///
    /// - 各日の中で、所要時間がまるごと入る最初の枠を選ぶ（日をまたぐ枠は選ばない）
    /// - 開始時刻は15分単位に切り上げる
    static func suggest(duration: TimeInterval, from: Date, to: Date, busy: [DateInterval],
                        count: Int = 3, calendar: Calendar = .current) -> [DateInterval] {
        guard duration > 0, to > from, count > 0 else { return [] }
        let merged = merge(busy)
        var result: [DateInterval] = []
        var day = calendar.startOfDay(for: from)

        while day < to && result.count < count {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let windowStart = max(day, from)
            let windowEnd = min(nextDay, to)
            if let slot = firstGap(duration: duration, windowStart: windowStart, windowEnd: windowEnd, busy: merged) {
                result.append(slot)
            }
            day = nextDay
        }
        return result
    }

    private static func firstGap(duration: TimeInterval, windowStart: Date, windowEnd: Date,
                                 busy: [DateInterval]) -> DateInterval? {
        var cursor = roundUp(windowStart)
        for interval in busy {
            if interval.end <= cursor { continue }
            if interval.start >= windowEnd { break }
            if interval.start.timeIntervalSince(cursor) >= duration {
                break
            }
            cursor = max(cursor, roundUp(interval.end))
        }
        guard windowEnd.timeIntervalSince(cursor) >= duration else { return nil }
        return DateInterval(start: cursor, duration: duration)
    }

    /// 重なっている枠をまとめ、開始順に並べる
    static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var result: [DateInterval] = []
        for interval in sorted {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }

    static func roundUp(_ date: Date) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (t / step).rounded(.up) * step)
    }
}
