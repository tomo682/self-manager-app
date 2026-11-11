import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// ウィジェットで選ぶ「テーマ」
struct ThemeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "テーマ"
    static var defaultQuery = ThemeQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ThemeQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ThemeEntity] {
        try allThemes().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ThemeEntity] {
        try allThemes()
    }

    private func allThemes() throws -> [ThemeEntity] {
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<TodoTheme>(sortBy: [SortDescriptor(\.sortOrder)])
        return try context.fetch(descriptor).map { ThemeEntity(id: $0.id, name: $0.name) }
    }
}

/// ウィジェットのボタンでTo doを達成にする
struct CompleteTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "To doを達成にする"
    static var isDiscoverable: Bool = false

    @Parameter(title: "To do ID")
    var todoID: String

    init() {}

    init(todoID: UUID) {
        self.todoID = todoID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoID) else { return .result() }
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        if let item = try context.fetch(descriptor).first, item.status == .active {
            TodoActions.complete(item)
            try context.save()
            AppGroup.markChangedByWidget()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
