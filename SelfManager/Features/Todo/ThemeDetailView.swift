import SwiftData
import SwiftUI

/// テーマ内の未達成To do一覧
struct ThemeDetailView: View {
    let theme: TodoTheme

    @Environment(\.modelContext) private var context
    @State private var editingTodo: TodoEditTarget?
    @State private var showTemplateEditor = false

    var body: some View {
        List {
            Section {
                let items = theme.activeItems
                if items.isEmpty {
                    Text("未達成のTo doはありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    TodoRowView(item: item) {
                        complete(item)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTodo = .edit(item) }
                }
            }

            Section {
                NavigationLink {
                    RecurringTemplateListView(theme: theme)
                } label: {
                    Label("習慣To do", systemImage: "repeat")
                }
                NavigationLink {
                    ArchiveView(theme: theme)
                } label: {
                    Label("達成・未達成の記録", systemImage: "archivebox")
                }
            }
        }
        .navigationTitle(theme.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editingTodo = .new
                    } label: {
                        Label("To doを追加", systemImage: "checkmark.circle")
                    }
                    Button {
                        showTemplateEditor = true
                    } label: {
                        Label("習慣To doを追加", systemImage: "repeat")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingTodo) { target in
            TodoEditView(target: target, theme: theme)
        }
        .sheet(isPresented: $showTemplateEditor) {
            RecurringTemplateEditView(template: nil, theme: theme)
        }
    }

    private func complete(_ item: TodoItem) {
        withAnimation {
            TodoActions.complete(item)
        }
        try? context.save()
        TodoActions.reloadWidgets()
    }
}

struct TodoRowView: View {
    let item: TodoItem
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                HStack(spacing: 4) {
                    if item.isRecurring {
                        Image(systemName: "repeat")
                    }
                    if let due = item.dueDate {
                        Text("期限 \(DateText.short(due))")
                    }
                }
                .font(.caption)
                .foregroundStyle(item.isOverdue() ? .red : .secondary)

                if !item.memo.isEmpty {
                    Text(item.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
