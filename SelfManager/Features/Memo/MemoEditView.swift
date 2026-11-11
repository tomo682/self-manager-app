import SwiftData
import SwiftUI

struct MemoEditView: View {
    @Bindable var memo: Memo

    @Environment(\.modelContext) private var context
    @Query(sort: \MemoTheme.sortOrder) private var themes: [MemoTheme]
    @State private var showSortSuggestion = false
    @State private var originalText = ""
    @FocusState private var bodyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("タイトル", text: $memo.title)
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top, 8)

            if memo.theme == nil {
                Button {
                    showSortSuggestion = true
                } label: {
                    Label("テーマ候補を見る（重複単語から提案）", systemImage: "wand.and.stars")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.top, 8)
                .disabled(memo.isEmpty)
            }

            TextEditor(text: $memo.body)
                .focused($bodyFocused)
                .padding(.horizontal, 12)
        }
        .navigationTitle(memo.theme?.name ?? "未分類")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    memo.isFavorite.toggle()
                } label: {
                    Image(systemName: memo.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(memo.isFavorite ? .yellow : .accentColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("テーマ", selection: $memo.theme) {
                        Text("未分類").tag(MemoTheme?.none)
                        ForEach(themes) { theme in
                            Text(theme.name).tag(Optional(theme))
                        }
                    }
                    Divider()
                    Button {
                        showSortSuggestion = true
                    } label: {
                        Label("重複単語からテーマを提案", systemImage: "wand.and.stars")
                    }
                    .disabled(memo.isEmpty)
                } label: {
                    Image(systemName: "folder")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { bodyFocused = false }
            }
        }
        .sheet(isPresented: $showSortSuggestion) {
            MemoSortSuggestionView(memo: memo)
        }
        .onAppear {
            memo.lastOpenedAt = .now
            originalText = memo.title + "\u{0}" + memo.body
            if memo.isEmpty { bodyFocused = true }
        }
        .onDisappear(perform: finish)
    }

    private func finish() {
        if memo.isEmpty {
            context.delete(memo)
        } else if memo.title + "\u{0}" + memo.body != originalText || memo.tokens.isEmpty {
            memo.updatedAt = .now
            memo.tokens = MemoTokenizer.tokens(from: memo.title + "\n" + memo.body)
        }
        try? context.save()
    }
}

/// 重複単語の数からテーマ候補を並べ、選んだテーマに移す
struct MemoSortSuggestionView: View {
    let memo: Memo

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoTheme.sortOrder) private var themes: [MemoTheme]
    @State private var scores: [MemoTokenizer.Score<UUID>]?

    var body: some View {
        NavigationStack {
            List {
                if let scores {
                    Section {
                        if scores.isEmpty {
                            Text(themes.isEmpty
                                 ? "テーマがまだありません。メモタブの＋からテーマを作ってください。"
                                 : "どのテーマのメモとも重複する単語がありませんでした。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(scores, id: \.id) { score in
                            if let theme = themes.first(where: { $0.id == score.id }) {
                                Button {
                                    memo.theme = theme
                                    dismiss()
                                } label: {
                                    HStack {
                                        Label(theme.name, systemImage: "folder")
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("重複 \(score.count)語")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("このメモの単語と、各テーマのメモに出てくる単語が何語重なっているかで並べています。タップでそのテーマに移動します。")
                    }

                    if !themes.isEmpty {
                        Section("その他のテーマ") {
                            ForEach(themes.filter { t in !scores.contains { $0.id == t.id } }) { theme in
                                Button {
                                    memo.theme = theme
                                    dismiss()
                                } label: {
                                    Label(theme.name, systemImage: "folder")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("テーマの候補")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { compute() }
        }
        .presentationDetents([.medium, .large])
    }

    private func compute() {
        let tokens = Set(MemoTokenizer.tokens(from: memo.title + "\n" + memo.body))
        let groups: [(id: UUID, tokens: Set<String>)] = themes.map { theme in
            let words = theme.memos
                .filter { $0.id != memo.id }
                .flatMap(\.tokens)
            return (id: theme.id, tokens: Set(words))
        }
        scores = Array(MemoTokenizer.rank(tokens, against: groups).prefix(5))
    }
}
