import Foundation

enum RecurrenceKind: String, Codable, CaseIterable {
    case weekly
    case monthly
}

/// 習慣To doの繰り返し設定
struct RecurrenceSpec: Equatable {
    var kind: RecurrenceKind
    /// 毎週: 1(日)〜7(土) / 毎月: 1〜31
    var startValue: Int
    var dueValue: Int
    var dueHour: Int
    var dueMinute: Int
}

/// 習慣To doの1回分
struct Occurrence: Equatable {
    let periodKey: String
    let showDate: Date
    let dueDate: Date
}

enum RecurrenceEngine {
    /// 作成日時より後に期限を迎える回のうち、now の時点で表示開始日を過ぎているものを返す
    ///
    /// - 毎週: 開始曜日の0時に表示。期限は開始日から見て次に来る期限曜日（同じ曜日なら当日）
    /// - 毎月: 開始日の0時に表示。期限日が開始日より前なら翌月の期限日
    /// - その月にない日付（31日など）は月末に置き換える
    static func occurrences(for spec: RecurrenceSpec, createdAt: Date, now: Date,
                            calendar: Calendar = .current) -> [Occurrence] {
        guard now >= createdAt else { return [] }
        switch spec.kind {
        case .weekly:
            return weekly(spec, createdAt: createdAt, now: now, calendar: calendar)
        case .monthly:
            return monthly(spec, createdAt: createdAt, now: now, calendar: calendar)
        }
    }

    private static func weekly(_ spec: RecurrenceSpec, createdAt: Date, now: Date,
                               calendar: Calendar) -> [Occurrence] {
        guard (1...7).contains(spec.startValue), (1...7).contains(spec.dueValue) else { return [] }
        let createdDay = calendar.startOfDay(for: createdAt)
        guard var show = calendar.date(byAdding: .day, value: -7, to: createdDay) else { return [] }
        while calendar.component(.weekday, from: show) != spec.startValue {
            guard let next = calendar.date(byAdding: .day, value: 1, to: show) else { return [] }
            show = next
        }

        let offset = (spec.dueValue - spec.startValue + 7) % 7
        var result: [Occurrence] = []
        while show <= now {
            if let dueDay = calendar.date(byAdding: .day, value: offset, to: show),
               let due = dueTime(on: dueDay, spec: spec, calendar: calendar),
               due > createdAt {
                result.append(Occurrence(periodKey: key(for: show, calendar: calendar),
                                         showDate: show, dueDate: due))
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: show) else { break }
            show = next
        }
        return result
    }

    private static func monthly(_ spec: RecurrenceSpec, createdAt: Date, now: Date,
                                calendar: Calendar) -> [Occurrence] {
        guard (1...31).contains(spec.startValue), (1...31).contains(spec.dueValue) else { return [] }
        guard let createdMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: createdAt)),
              var month = calendar.date(byAdding: .month, value: -1, to: createdMonth) else { return [] }

        var result: [Occurrence] = []
        while true {
            let show = day(spec.startValue, inMonthStarting: month, calendar: calendar)
            if show > now { break }
            let dueMonth = spec.dueValue >= spec.startValue
                ? month
                : (calendar.date(byAdding: .month, value: 1, to: month) ?? month)
            let dueDay = day(spec.dueValue, inMonthStarting: dueMonth, calendar: calendar)
            if let due = dueTime(on: dueDay, spec: spec, calendar: calendar), due > createdAt {
                result.append(Occurrence(periodKey: key(for: show, calendar: calendar),
                                         showDate: show, dueDate: due))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    /// 月初の日付から、その月の day 日を返す（月にない日は月末）
    static func day(_ day: Int, inMonthStarting monthStart: Date, calendar: Calendar) -> Date {
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 28
        let clamped = min(max(day, 1), daysInMonth)
        return calendar.date(byAdding: .day, value: clamped - 1, to: monthStart) ?? monthStart
    }

    private static func dueTime(on day: Date, spec: RecurrenceSpec, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: spec.dueHour, minute: spec.dueMinute, second: 0, of: day)
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
