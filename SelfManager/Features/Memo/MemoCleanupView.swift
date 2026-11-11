import SwiftData
import SwiftUI

/// データ整理：しばらく開いていないメモの削除を提案する（⭐️付きは対象外）
struct MemoCleanupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Memo.lastOpenedAt) private var memos: [Memo]
    @State private var selected: Set<UUID> = []
    @State private var confirmDelete = false

    private var staleMemos: [Memo] {
        let limit = Calendar.current.date(byAdding: .day, value: -AppSettings.memoCleanupDays, to: .now) ?? .now
        return memos.filter { !$0.isFavorite && $0.lastOpenedAt < limit }
    }

    var body: some View {
        let list = staleMemos
        List {
            Section {
                if list.isEmpty {
                    Text("整理が必要なメモはありません 🎉")
                        .foregroundStyle(.secondary)
                }
                ForEach(list) { memo in
                    HStack(spacing: 12) {
                        Image(systemName: selected.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected.contains(memo.id) ? Color.red : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memo.displayTitle).lineLimit(1)
                            Text("最後に開いた日: \(DateText.fullDay(memo.lastOpenedAt))・\(memo.theme?.name ?? "未分類")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            memo.isFavorite = true
                            selected.remove(memo.id)
                            try? context.save()
                        } label: {
                            Image(systemName: "star")
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(memo.id) {
                            selected.remove(memo.id)
                        } else {
                            selected.insert(memo.id)
                        }
                    }
                }
            } header: {
                Text("\(AppSettings.memoCleanupDays)日以上開いていないメモ")
            } footer: {
                Text("⭐️付きのメモは表示されません。残したいメモは右の☆をタップすると⭐️が付き、一覧から外れます。")
            }
        }
        .navigationTitle("データ整理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(selected.count == list.count && !list.isEmpty ? "選択解除" : "すべて選択") {
                    if selected.count == list.count {
                        selected = []
                    } else {
                        selected = Set(list.map(\.id))
                    }
                }
                .disabled(list.isEmpty)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("選択したメモを削除（\(selected.count)件）", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(selected.isEmpty)
            }
        }
        .confirmationDialog("\(selected.count)件のメモを削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                for memo in memos where selected.contains(memo.id) {
                    context.delete(memo)
                }
                selected = []
                try? context.save()
            }
        } message: {
            Text("削除したメモは元に戻せません。")
        }
    }
}
