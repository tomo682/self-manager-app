import Foundation
import SwiftData
import WidgetKit

enum TodoActions {
    static func complete(_ item: TodoItem, at date: Date = .now) {
        item.status = .completed
        item.completedAt = date
    }

    /// 達成したものを未達成に戻す
    static func restore(_ item: TodoItem) {
        item.status = .active
        item.completedAt = nil
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum TodoMaintenance {
    /// 習慣To doの新しい回を作り、期限切れの回を「未達成」に移す
    /// - Returns: データを変更したかどうか
    @discardableResult
    static func run(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Bool {
        var changed = false

        let templates = (try? context.fetch(FetchDescriptor<RecurringTodoTemplate>())) ?? []
        for template in templates where template.isActive {
            let known = Set(template.generatedKeys)
            let occurrences = RecurrenceEngine.occurrences(
                for: template.spec, createdAt: template.createdAt, now: now, calendar: calendar)
            for occurrence in occurrences where !known.contains(occurrence.periodKey) {
                let item = TodoItem(title: template.title, memo: template.memo, dueDate: occurrence.dueDate)
                item.isRecurring = true
                item.periodKey = occurrence.periodKey
                context.insert(item)
                item.theme = template.theme
                item.sourceTemplate = template
                template.generatedKeys.append(occurrence.periodKey)
                changed = true
            }
        }

        let activeRaw = TodoStatus.active.rawValue
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.statusRaw == activeRaw })
        let activeItems = (try? context.fetch(descriptor)) ?? []
        for item in activeItems where item.isRecurring {
            if let due = item.dueDate, due < now {
                item.status = .missed
                item.completedAt = due
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
        return changed
    }
}
