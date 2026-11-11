import SwiftData
import SwiftUI

enum TodoEditTarget: Identifiable {
    case new
    case edit(TodoItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let item): return item.id.uuidString
        }
    }
}

struct TodoEditView: View {
    let target: TodoEditTarget
    let theme: TodoTheme

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var memo = ""
    @State private var hasDue = false
    @State private var dueDate = TodoEditView.defaultDue()
    @State private var showSlots = false
    @State private var confirmDelete = false
    @State private var loaded = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Toggle("期限を設定", isOn: $hasDue)
                    if hasDue {
                        DatePicker("期限", selection: $dueDate)
                    }
                }

                Section {
                    Button {
                        showSlots = true
                    } label: {
                        Label("いつやる？（空き時間を提案）", systemImage: "calendar.badge.clock")
                    }
                    .disabled(trimmedTitle.isEmpty)
                } footer: {
                    Text("カレンダーの予定と、設定で登録した習慣的な予定（学校・睡眠など）を避けて、空いている時間を3つ提案します。")
                }

                if case .edit = target {
                    Section {
                        Button("このTo doを削除", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "新しいTo do" : "To doを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .sheet(isPresented: $showSlots) {
                SlotSuggestionView(title: trimmedTitle, deadline: hasDue ? dueDate : nil)
            }
            .confirmationDialog("このTo doを削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) { delete() }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if case .edit(let item) = target {
            title = item.title
            memo = item.memo
            hasDue = item.dueDate != nil
            dueDate = item.dueDate ?? TodoEditView.defaultDue()
        }
    }

    private func save() {
        switch target {
        case .new:
            let item = TodoItem(title: trimmedTitle, memo: memo, dueDate: hasDue ? dueDate : nil)
            context.insert(item)
            item.theme = theme
        case .edit(let item):
            item.title = trimmedTitle
            item.memo = memo
            item.dueDate = hasDue ? dueDate : nil
        }
        try? context.save()
        TodoActions.reloadWidgets()
        dismiss()
    }

    private func delete() {
        if case .edit(let item) = target {
            context.delete(item)
            try? context.save()
            TodoActions.reloadWidgets()
        }
        dismiss()
    }

    /// 明日の23:59
    static func defaultDue() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: tomorrow) ?? tomorrow
    }
}
