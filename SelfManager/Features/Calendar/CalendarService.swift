import EventKit
import SwiftUI
import UIKit

enum CalendarError: LocalizedError {
    case noWritableSource
    case calendarNotFound

    var errorDescription: String? {
        switch self {
        case .noWritableSource: return "カレンダーを作成できるアカウントが見つかりません。iCloudのカレンダーがオンになっているか確認してください。"
        case .calendarNotFound: return "カレンダーが見つかりません。"
        }
    }
}

/// iPhone 標準カレンダー（EventKit）とのやりとり
@MainActor
final class CalendarService: ObservableObject {
    let store = EKEventStore()

    @Published private(set) var isAuthorized = false
    /// 予定が変わるたびに更新される（画面の再描画用）
    @Published private(set) var changeToken = UUID()
    /// 提案した予定の登録先（nil なら「To do」カレンダーを自動で使う）
    @Published var taskCalendarIdentifier: String? {
        didSet { UserDefaults.standard.set(taskCalendarIdentifier, forKey: AppSettings.taskCalendarIdentifierKey) }
    }

    private var observer: NSObjectProtocol?

    init() {
        taskCalendarIdentifier = UserDefaults.standard.string(forKey: AppSettings.taskCalendarIdentifierKey)
        updateStatus()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.changeToken = UUID() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - 権限

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// 一度拒否されていて、設定アプリから許可する必要があるか
    var needsSettingsApp: Bool {
        switch authorizationStatus {
        case .denied, .restricted, .writeOnly: return true
        default: return false
        }
    }

    func updateStatus() {
        isAuthorized = authorizationStatus == .fullAccess
    }

    func requestAccess() async {
        do {
            isAuthorized = try await store.requestFullAccessToEvents()
        } catch {
            isAuthorized = false
        }
        changeToken = UUID()
    }

    // MARK: - 予定

    func events(from start: Date, to end: Date) -> [EKEvent] {
        guard isAuthorized, end > start else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func newEvent() -> EKEvent {
        EKEvent(eventStore: store)
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        try store.save(event, span: span, commit: true)
    }

    func delete(_ event: EKEvent, span: EKSpan) throws {
        try store.remove(event, span: span, commit: true)
    }

    /// 空き時間の提案で選んだ枠を登録する
    func addTaskEvent(title: String, interval: DateInterval) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = interval.start
        event.endDate = interval.end
        event.calendar = try taskCalendar()
        try store.save(event, span: .thisEvent, commit: true)
    }

    // MARK: - カレンダー（カテゴリ）

    var allCalendars: [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// 予定を追加・編集できるカレンダー
    var writableCalendars: [EKCalendar] {
        allCalendars.filter(\.allowsContentModifications)
    }

    var defaultCalendar: EKCalendar? {
        store.defaultCalendarForNewEvents
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        store.calendar(withIdentifier: identifier)
    }

    func createCalendar(title: String, color: Color) throws -> EKCalendar {
        var lastError: Error = CalendarError.noWritableSource
        for source in candidateSources() {
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = title
            calendar.cgColor = UIColor(color).cgColor
            calendar.source = source
            do {
                try store.saveCalendar(calendar, commit: true)
                return calendar
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func updateCalendar(_ calendar: EKCalendar, title: String, color: Color) throws {
        calendar.title = title
        calendar.cgColor = UIColor(color).cgColor
        try store.saveCalendar(calendar, commit: true)
    }

    func deleteCalendar(_ calendar: EKCalendar) throws {
        try store.removeCalendar(calendar, commit: true)
        if taskCalendarIdentifier == calendar.calendarIdentifier {
            taskCalendarIdentifier = nil
        }
    }

    /// 提案した予定の登録先。未設定なら「To do」カレンダーを探すか作る
    func taskCalendar() throws -> EKCalendar {
        if let id = taskCalendarIdentifier,
           let calendar = store.calendar(withIdentifier: id),
           calendar.allowsContentModifications {
            return calendar
        }
        if let existing = writableCalendars.first(where: { $0.title == "To do" }) {
            taskCalendarIdentifier = existing.calendarIdentifier
            return existing
        }
        let created = try createCalendar(title: "To do", color: .orange)
        taskCalendarIdentifier = created.calendarIdentifier
        return created
    }

    /// カレンダーを作る候補のアカウント（デフォルト → iCloud → このiPhone）
    private func candidateSources() -> [EKSource] {
        var result: [EKSource] = []
        func add(_ source: EKSource?) {
            guard let source, !result.contains(where: { $0.sourceIdentifier == source.sourceIdentifier }) else { return }
            result.append(source)
        }
        add(store.defaultCalendarForNewEvents?.source)
        add(store.sources.first { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") })
        add(store.sources.first { $0.sourceType == .local })
        store.sources.filter { $0.sourceType == .calDAV }.forEach { add($0) }
        return result
    }
}

extension EKCalendar {
    var swiftUIColor: Color {
        Color(cgColor: cgColor ?? UIColor.systemGray.cgColor)
    }
}

extension EKEvent {
    var timeText: String {
        if isAllDay { return "終日" }
        return "\(DateText.time(startDate))〜\(DateText.time(endDate))"
    }
}
