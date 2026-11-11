import Foundation
import Testing
@testable import SelfManager

struct SlotFinderTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    var sleep: HabitRule {
        HabitRule(weekdays: Set(1...7), startMinutes: 23 * 60, endMinutes: 7 * 60,
                  validFrom: nil, validTo: nil, exceptionDates: [])
    }

    func school(exceptions: [Date] = [], validTo: Date? = nil) -> HabitRule {
        HabitRule(weekdays: [2, 3, 4, 5, 6], startMinutes: 8 * 60 + 30, endMinutes: 16 * 60,
                  validFrom: nil, validTo: validTo, exceptionDates: exceptions)
    }

    @Test func 日をまたぐ習慣は前日分も含める() {
        let intervals = SlotFinder.habitIntervals([sleep], from: date(2026, 11, 11), to: date(2026, 11, 12), calendar: calendar)
        #expect(intervals.contains(DateInterval(start: date(2026, 11, 10, 23), end: date(2026, 11, 11, 7))))
        #expect(intervals.contains(DateInterval(start: date(2026, 11, 11, 23), end: date(2026, 11, 12, 7))))
    }

    @Test func 別々の日から3つ提案する() {
        let from = date(2026, 11, 11, 8) // 水曜 8:00
        let to = date(2026, 11, 20)
        let busy = SlotFinder.habitIntervals([sleep, school()], from: from, to: to, calendar: calendar)
        let slots = SlotFinder.suggest(duration: 3600, from: from, to: to, busy: busy, calendar: calendar)
        // 11/11 は 8:00〜8:30 が30分しかないので 16:00、翌日以降は起床後の 7:00〜8:30 に入る
        #expect(slots.map(\.start) == [date(2026, 11, 11, 16), date(2026, 11, 12, 7), date(2026, 11, 13, 7)])
        #expect(slots.allSatisfy { $0.duration == 3600 })
    }

    @Test func カレンダーの予定も避ける() {
        let from = date(2026, 11, 11, 8)
        let to = date(2026, 11, 12)
        let event = DateInterval(start: date(2026, 11, 11, 16), end: date(2026, 11, 11, 18, 10))
        let busy = SlotFinder.habitIntervals([sleep, school()], from: from, to: to, calendar: calendar) + [event]
        let slots = SlotFinder.suggest(duration: 3600, from: from, to: to, busy: busy, calendar: calendar)
        // 18:10 終わり → 15分単位に切り上げて 18:15
        #expect(slots.first?.start == date(2026, 11, 11, 18, 15))
    }

    @Test func 例外の日は習慣予定がない() {
        let from = date(2026, 11, 11, 8)
        let to = date(2026, 11, 13)
        let withoutException = SlotFinder.suggest(
            duration: 2 * 3600, from: from, to: to,
            busy: SlotFinder.habitIntervals([sleep, school()], from: from, to: to, calendar: calendar),
            calendar: calendar)
        #expect(withoutException.map(\.start) == [date(2026, 11, 11, 16), date(2026, 11, 12, 16)])

        let withException = SlotFinder.suggest(
            duration: 2 * 3600, from: from, to: to,
            busy: SlotFinder.habitIntervals([sleep, school(exceptions: [date(2026, 11, 12)])], from: from, to: to, calendar: calendar),
            calendar: calendar)
        #expect(withException.map(\.start) == [date(2026, 11, 11, 16), date(2026, 11, 12, 7)])
    }

    @Test func 有効期間の外は習慣予定がない() {
        let from = date(2026, 11, 12)
        let to = date(2026, 11, 13)
        let busy = SlotFinder.habitIntervals([school(validTo: date(2026, 11, 11))], from: from, to: to, calendar: calendar)
        #expect(busy.isEmpty)
    }

    @Test func 期限までに入らなければ空() {
        let slots = SlotFinder.suggest(duration: 3600, from: date(2026, 11, 11, 16), to: date(2026, 11, 11, 16, 30),
                                       busy: [], calendar: calendar)
        #expect(slots.isEmpty)
    }

    @Test func 重なる予定はまとめる() {
        let merged = SlotFinder.merge([
            DateInterval(start: date(2026, 11, 11, 10), end: date(2026, 11, 11, 12)),
            DateInterval(start: date(2026, 11, 11, 11), end: date(2026, 11, 11, 13)),
            DateInterval(start: date(2026, 11, 11, 15), end: date(2026, 11, 11, 16)),
        ])
        #expect(merged.count == 2)
        #expect(merged.first?.end == date(2026, 11, 11, 13))
    }
}
