import Foundation
import SwiftData

enum TodoStatus: String, Codable, CaseIterable {
    case active      // 未達成（表示中）
    case completed   // 達成
    case missed      // 期限切れで未達成（習慣To doのみ自動で移る）
}

@Model
final class TodoTheme {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TodoItem.theme)
    var items: [TodoItem] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringTodoTemplate.theme)
    var templates: [RecurringTodoTemplate] = []

    init(name: String, colorHex: String, sortOrder: Int) {
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    /// 未達成のTo do（期限が近い順）
    var activeItems: [TodoItem] {
        items.filter { $0.status == .active }.sorted(by: TodoSort.byDue)
    }
}

@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var memo: String = ""
    var dueDate: Date?
    var statusRaw: String = "active"
    var createdAt: Date = Date()
    /// 達成した日時（未達成として記録されたものは期限の日時）
    var completedAt: Date?
    /// 習慣To doから作られたものかどうか
    var isRecurring: Bool = false
    /// 習慣To doの「何回目か」を表すキー（例: 2026-11-09）
    var periodKey: String?
    var theme: TodoTheme?
    var sourceTemplate: RecurringTodoTemplate?

    init(title: String, memo: String = "", dueDate: Date? = nil) {
        self.title = title
        self.memo = memo
        self.dueDate = dueDate
    }

    var status: TodoStatus {
        get { TodoStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    func isOverdue(at now: Date = .now) -> Bool {
        guard status == .active, let dueDate else { return false }
        return dueDate < now
    }
}

@Model
final class RecurringTodoTemplate {
    var id: UUID = UUID()
    var title: String = ""
    var memo: String = ""
    var kindRaw: String = "weekly"
    /// 毎週: 表示開始の曜日（1=日 … 7=土） / 毎月: 表示開始の日（1〜31）
    var startValue: Int = 2
    /// 毎週: 期限の曜日（1=日 … 7=土） / 毎月: 期限の日（1〜31）
    var dueValue: Int = 6
    var dueHour: Int = 23
    var dueMinute: Int = 59
    var isActive: Bool = true
    var createdAt: Date = Date()
    /// すでに作成した回のキー（To doを手動で消しても作り直さないため）
    var generatedKeys: [String] = []
    var theme: TodoTheme?

    @Relationship(deleteRule: .nullify, inverse: \TodoItem.sourceTemplate)
    var items: [TodoItem] = []

    init(title: String) {
        self.title = title
    }

    var kind: RecurrenceKind {
        get { RecurrenceKind(rawValue: kindRaw) ?? .weekly }
        set { kindRaw = newValue.rawValue }
    }

    var spec: RecurrenceSpec {
        RecurrenceSpec(kind: kind, startValue: startValue, dueValue: dueValue,
                       dueHour: dueHour, dueMinute: dueMinute)
    }
}

enum TodoSort {
    /// 期限が近い順（期限なしは最後）。同じなら作成順
    static func byDue(_ a: TodoItem, _ b: TodoItem) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.createdAt < b.createdAt
        }
    }
}
