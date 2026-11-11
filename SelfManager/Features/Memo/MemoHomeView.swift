import SwiftData
import SwiftUI

enum MemoFolder: Hashable {
    case unfiled
    case favorites
    case theme(MemoTheme)
}

/// メモタブのトップ：テーマ（ファイル）一覧
struct MemoHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MemoTheme.sortOrder) private var themes: [MemoTheme]
    @Query private var memos: [Memo]
    @State private var path = NavigationPath()
    @State private var showNewTheme = false
    @State private var themeName = ""
    @State private var renamingTheme: MemoTheme?
    @State private var themeToDelete: MemoTheme?
    @State private var showCleanup = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: MemoFolder.unfiled) {
                        Label("未分類", systemImage: "tray")
                            .badge(memos.filter { $0.theme == nil }.count)
                    }
                    NavigationLink(value: MemoFolder.favorites) {
                        Label("お気に入り", systemImage: "star")
                            .badge(memos.filter(\.isFavorite).count)
                    }
                }

                Section("テーマ") {
                    if themes.isEmpty {
                        Text("右上の＋からテーマを作れます")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(themes) { theme in
                        NavigationLink(value: MemoFolder.theme(theme)) {
                            Label(theme.name, systemImage: "folder")
                                .badge(theme.memos.count)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                themeToDelete = theme
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                            Button {
                                themeName = theme.name
                                renamingTheme = theme
                            } label: {
                                Label("名前変更", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                    .onMove(perform: move)
                }

                Section {
                    Button {
                        showCleanup = true
                    } label: {
                        Label("データ整理", systemImage: "sparkles")
                    }
                } footer: {
                    Text("\(AppSettings.memoCleanupDays)日以上開いていないメモ（⭐️以外）の削除を提案します。")
                }
            }
            .navigationTitle("メモ")
            .navigationDestination(for: MemoFolder.self) { folder in
                MemoListView(folder: folder, path: $path)
            }
            .navigationDestination(for: Memo.self) { memo in
                MemoEditView(memo: memo)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            let memo = Memo()
                            context.insert(memo)
                            path.append(memo)
                        } label: {
                            Label("新しいメモ", systemImage: "square.and.pencil")
                        }
                        Button {
                            themeName = ""
                            showNewTheme = true
                        } label: {
                            Label("新しいテーマ", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("新しいテーマ", isPresented: $showNewTheme) {
                TextField("テーマ名", text: $themeName)
                Button("キャンセル", role: .cancel) {}
                Button("作成") { createTheme() }
            }
            .alert("名前を変更", isPresented: Binding(presenting: $renamingTheme), presenting: renamingTheme) { theme in
                TextField("テーマ名", text: $themeName)
                Button("キャンセル", role: .cancel) {}
                Button("変更") {
                    let name = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        theme.name = name
                        try? context.save()
                    }
                }
            }
            .confirmationDialog(
                "テーマを削除しますか？",
                isPresented: Binding(presenting: $themeToDelete),
                titleVisibility: .visible,
                presenting: themeToDelete
            ) { theme in
                Button("削除", role: .destructive) {
                    context.delete(theme)
                    try? context.save()
                }
            } message: { theme in
                Text("「\(theme.name)」のメモは削除されず、「未分類」に移ります。")
            }
            .sheet(isPresented: $showCleanup) {
                NavigationStack {
                    MemoCleanupView()
                }
            }
        }
    }

    private func createTheme() {
        let name = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let order = (themes.map(\.sortOrder).max() ?? -1) + 1
        context.insert(MemoTheme(name: name, sortOrder: order))
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = themes
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, theme) in ordered.enumerated() {
            theme.sortOrder = index
        }
        try? context.save()
    }
}

/// テーマ内のメモ一覧
struct MemoListView: View {
    let folder: MemoFolder
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var context
    @Query(sort: \Memo.updatedAt, order: .reverse) private var allMemos: [Memo]

    private var memos: [Memo] {
        let filtered: [Memo]
        switch folder {
        case .unfiled: filtered = allMemos.filter { $0.theme == nil }
        case .favorites: filtered = allMemos.filter(\.isFavorite)
        case .theme(let theme): filtered = allMemos.filter { $0.theme?.id == theme.id }
        }
        // ⭐️を上に
        return filtered.filter(\.isFavorite) + filtered.filter { !$0.isFavorite }
    }

    private var title: String {
        switch folder {
        case .unfiled: return "未分類"
        case .favorites: return "お気に入り"
        case .theme(let theme): return theme.name
        }
    }

    var body: some View {
        List {
            let list = memos
            if list.isEmpty {
                Text("メモはありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(list) { memo in
                NavigationLink(value: memo) {
                    MemoRowView(memo: memo, showsTheme: folder == .favorites)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        memo.isFavorite.toggle()
                        try? context.save()
                    } label: {
                        Label(memo.isFavorite ? "⭐️を外す" : "⭐️を付ける", systemImage: memo.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(memo)
                        try? context.save()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            if folder != .favorites {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let memo = Memo()
                        context.insert(memo)
                        if case .theme(let theme) = folder {
                            memo.theme = theme
                        }
                        path.append(memo)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct MemoRowView: View {
    let memo: Memo
    var showsTheme = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if memo.isFavorite {
                    Text("⭐️").font(.caption)
                }
                Text(memo.displayTitle)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(DateText.day(memo.updatedAt))
                if showsTheme {
                    Text(memo.theme?.name ?? "未分類")
                }
                let preview = memo.body.replacingOccurrences(of: "\n", with: " ")
                if !preview.isEmpty && !memo.title.isEmpty {
                    Text(preview).lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
