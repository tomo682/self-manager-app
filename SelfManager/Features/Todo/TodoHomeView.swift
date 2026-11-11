import SwiftData
import SwiftUI

/// To do タブのトップ：テーマ一覧
struct TodoHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTheme.sortOrder) private var themes: [TodoTheme]
    @State private var editingTheme: ThemeEditTarget?
    @State private var themeToDelete: TodoTheme?

    var body: some View {
        NavigationStack {
            List {
                ForEach(themes) { theme in
                    NavigationLink {
                        ThemeDetailView(theme: theme)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: theme.colorHex))
                                .frame(width: 12, height: 12)
                            Text(theme.name)
                            Spacer()
                            let count = theme.activeItems.count
                            if count > 0 {
                                Text("\(count)").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            themeToDelete = theme
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        Button {
                            editingTheme = .edit(theme)
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
                .onMove(perform: move)
            }
            .overlay {
                if themes.isEmpty {
                    ContentUnavailableView(
                        "テーマがありません",
                        systemImage: "folder",
                        description: Text("右上の＋から「仕事」「課題」「部活」などのテーマを作りましょう")
                    )
                }
            }
            .navigationTitle("To do")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !themes.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingTheme = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingTheme) { target in
                ThemeEditSheet(target: target)
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
                    TodoActions.reloadWidgets()
                }
            } message: { theme in
                Text("「\(theme.name)」のTo do・習慣To do・達成記録もすべて削除されます。")
            }
        }
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

enum ThemeEditTarget: Identifiable {
    case new
    case edit(TodoTheme)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let theme): return theme.id.uuidString
        }
    }
}

struct ThemeEditSheet: View {
    let target: ThemeEditTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TodoTheme.sortOrder) private var themes: [TodoTheme]
    @State private var name = ""
    @State private var color: Color = .blue
    @State private var loaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("テーマ名（例：仕事、課題、部活）", text: $name)
                ColorPicker("色", selection: $color, supportsOpacity: false)
            }
            .navigationTitle(isNew ? "新しいテーマ" : "テーマを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.medium])
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch target {
        case .new:
            color = Color(hex: ThemePalette.color(at: themes.count))
        case .edit(let theme):
            name = theme.name
            color = Color(hex: theme.colorHex)
        }
    }

    private func save() {
        switch target {
        case .new:
            let order = (themes.map(\.sortOrder).max() ?? -1) + 1
            context.insert(TodoTheme(name: trimmedName, colorHex: color.hexString, sortOrder: order))
        case .edit(let theme):
            theme.name = trimmedName
            theme.colorHex = color.hexString
        }
        try? context.save()
        TodoActions.reloadWidgets()
        dismiss()
    }
}
