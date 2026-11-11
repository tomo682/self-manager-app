import Foundation
import SwiftData

/// App Group 内に置いた SwiftData のストア。アプリとウィジェットで同じものを開く
enum SharedModelContainer {
    static let schema = Schema([
        TodoTheme.self,
        TodoItem.self,
        RecurringTodoTemplate.self,
        HabitSchedule.self,
        MemoTheme.self,
        Memo.self,
    ])

    /// ウィジェットやインテントから使う共有インスタンス
    static let shared: ModelContainer = make()

    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(
            "SelfManager",
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("データベースを開けませんでした: \(error)")
        }
    }
}
