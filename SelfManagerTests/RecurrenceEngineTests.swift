import Foundation
import Testing
@testable import SelfManager

struct RecurrenceEngineTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // 2026-11-11 は水曜日。月曜=11/9、金曜=11/13
    let monToFri = RecurrenceSpec(kind: .weekly, startValue: 2, dueValue: 6, dueHour: 23, dueMinute: 59)

    @Test func 週の途中で作ると今週分が表示される() {
        let created = date(2026, 11, 11, 10)
        let result = RecurrenceEngine.occurrences(for: monToFri, createdAt: created, now: created, calendar: calendar)
        #expect(result.count == 1)
        #expect(result.first?.periodKey == "2026-11-09")
        #expect(result.first?.showDate == date(2026, 11, 9))
        #expect(result.first?.dueDate == date(2026, 11, 13, 23, 59))
    }

    @Test func 期限後に作った週の分は作らない() {
        let created = date(2026, 11, 14, 10) // 土曜
        let result = RecurrenceEngine.occurrences(for: monToFri, createdAt: created, now: created, calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test func 週ごとに回が増える() {
        let created = date(2026, 11, 11, 10)
        let now = date(2026, 11, 25, 12)
        let keys = RecurrenceEngine.occurrences(for: monToFri, createdAt: created, now: now, calendar: calendar).map(\.periodKey)
        #expect(keys == ["2026-11-09", "2026-11-16", "2026-11-23"])
    }

    @Test func 期限曜日が開始曜日より前なら翌週() {
        let friToMon = RecurrenceSpec(kind: .weekly, startValue: 6, dueValue: 2, dueHour: 9, dueMinute: 0)
        let created = date(2026, 11, 13, 9)
        let result = RecurrenceEngine.occurrences(for: friToMon, createdAt: created, now: created, calendar: calendar)
        #expect(result.count == 1)
        #expect(result.first?.dueDate == date(2026, 11, 16, 9, 0))
    }

    @Test func 毎月_月にない日付は月末になる() {
        let spec = RecurrenceSpec(kind: .monthly, startValue: 25, dueValue: 31, dueHour: 23, dueMinute: 59)
        let created = date(2027, 2, 1)
        let now = date(2027, 2, 26)
        let result = RecurrenceEngine.occurrences(for: spec, createdAt: created, now: now, calendar: calendar)
        #expect(result.count == 1)
        #expect(result.first?.showDate == date(2027, 2, 25))
        #expect(result.first?.dueDate == date(2027, 2, 28, 23, 59))
    }

    @Test func 毎月_期限日が開始日より前なら翌月() {
        let spec = RecurrenceSpec(kind: .monthly, startValue: 25, dueValue: 5, dueHour: 23, dueMinute: 59)
        let created = date(2026, 11, 26)
        let result = RecurrenceEngine.occurrences(for: spec, createdAt: created, now: created, calendar: calendar)
        #expect(result.count == 1)
        #expect(result.first?.periodKey == "2026-11-25")
        #expect(result.first?.dueDate == date(2026, 12, 5, 23, 59))
    }

    @Test func 不正な曜日は何も作らない() {
        let spec = RecurrenceSpec(kind: .weekly, startValue: 0, dueValue: 9, dueHour: 0, dueMinute: 0)
        let created = date(2026, 11, 11)
        #expect(RecurrenceEngine.occurrences(for: spec, createdAt: created, now: created, calendar: calendar).isEmpty)
    }
}
