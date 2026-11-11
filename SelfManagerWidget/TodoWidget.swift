import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

@main
struct SelfManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
    }
}

struct SelectThemeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "テーマを選択"
    static var description = IntentDescription("ウィジェットに表示するTo doのテーマを選びます。")

    @Parameter(title: "テーマ")
    var theme: ThemeEntity?
}

struct TodoRowData: Identifiable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let isOverdue: Bool
}

struct TodoEntry: TimelineEntry {
    let date: Date
    let themeName: String?
    let themeColorHex: String
    let rows: [TodoRowData]
}

struct TodoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, themeName: "課題", themeColorHex: "#007AFF", rows: [
            TodoRowData(id: UUID(), title: "レポート提出", dueDate: .now.addingTimeInterval(86_400), isOverdue: false),
            TodoRowData(id: UUID(), title: "小テスト勉強", dueDate: nil, isOverdue: false),
        ])
    }

    func snapshot(for configuration: SelectThemeIntent, in context: Context) async -> TodoEntry {
        if context.isPreview && configuration.theme == nil {
            return placeholder(in: context)
        }
        return load(configuration)
    }

    func timeline(for configuration: SelectThemeIntent, in context: Context) async -> Timeline<TodoEntry> {
        let entry = load(configuration)
        let calendar = Calendar.current
        let in30min = Date.now.addingTimeInterval(30 * 60)
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? in30min)
        return Timeline(entries: [entry], policy: .after(min(in30min, tomorrow)))
    }

    private func load(_ configuration: SelectThemeIntent) -> TodoEntry {
        guard let themeID = configuration.theme?.id else {
            return TodoEntry(date: .now, themeName: nil, themeColorHex: "#007AFF", rows: [])
        }
        let context = ModelContext(SharedModelContainer.shared)
        if TodoMaintenance.run(in: context) {
            // アプリ側が古いデータのまま習慣To doを二重に作らないよう、再読み込みを促す
            AppGroup.markChangedByWidget()
        }

        let descriptor = FetchDescriptor<TodoTheme>(predicate: #Predicate { $0.id == themeID })
        guard let theme = try? context.fetch(descriptor).first else {
            return TodoEntry(date: .now, themeName: nil, themeColorHex: "#007AFF", rows: [])
        }
        let now = Date.now
        let rows = theme.activeItems.map {
            TodoRowData(id: $0.id, title: $0.title, dueDate: $0.dueDate, isOverdue: $0.isOverdue(at: now))
        }
        return TodoEntry(date: now, themeName: theme.name, themeColorHex: theme.colorHex, rows: rows)
    }
}

struct TodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodoEntry

    private var maxRows: Int {
        switch family {
        case .systemLarge: return 7
        default: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let name = entry.themeName {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: entry.themeColorHex))
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(entry.rows.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if entry.rows.isEmpty {
                    Spacer(minLength: 0)
                    Text("未達成のTo doはありません 🎉")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    ForEach(entry.rows.prefix(maxRows)) { row in
                        HStack(alignment: .top, spacing: 6) {
                            Button(intent: CompleteTodoIntent(todoID: row.id)) {
                                Image(systemName: "circle")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let due = row.dueDate {
                                    Text(DateText.short(due))
                                        .font(.caption2)
                                        .foregroundStyle(row.isOverdue ? .red : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
                Text("長押し →「ウィジェットを編集」からテーマを選んでください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectThemeIntent.self, provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("To do")
        .description("選んだテーマの未達成To doを表示し、ボタンで達成にできます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
