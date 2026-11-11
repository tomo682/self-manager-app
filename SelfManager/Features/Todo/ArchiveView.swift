import SwiftData
import SwiftUI

/// テーマごとの達成・未達成の記録
struct ArchiveView: View {
    let theme: TodoTheme

    @Environment(\.modelContext) private var context
    @State private var tab: TodoStatus = .completed

    private var items: [TodoItem] {
        theme.items
            .filter { $0.status == tab }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            Section {
                Picker("種類", selection: $tab) {
                    Text("達成").tag(TodoStatus.completed)
                    Text("未達成").tag(TodoStatus.missed)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                let list = items
                if list.isEmpty {
                    Text(tab == .completed ? "達成した記録はまだありません" : "未達成の記録はありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(list) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if item.isRecurring {
                                Image(systemName: "repeat").font(.caption)
                            }
                            Text(item.title)
                        }
                        if let date = item.completedAt {
                            Text(tab == .completed ? "達成: \(DateText.short(date))" : "期限: \(DateText.short(date))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !item.memo.isEmpty {
                            Text(item.memo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(item)
                            try? context.save()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if tab == .completed {
                            Button {
                                TodoActions.restore(item)
                                save()
                            } label: {
                                Label("未達成に戻す", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                TodoActions.complete(item)
                                save()
                            } label: {
                                Label("達成にする", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            } footer: {
                Text(tab == .completed ? "右にスワイプで未達成に戻せます。" : "右にスワイプで達成に変更できます。")
            }
        }
        .navigationTitle("\(theme.name)の記録")
    }

    private func save() {
        try? context.save()
        TodoMaintenance.run(in: context)
        TodoActions.reloadWidgets()
    }
}
