import Foundation
import SwiftData

@Model
final class MemoTheme {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// テーマを消してもメモは「未分類」に残す
    @Relationship(deleteRule: .nullify, inverse: \Memo.theme)
    var memos: [Memo] = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

@Model
final class Memo {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastOpenedAt: Date = Date()
    /// 本文から取り出した単語（重複なし）。仕分け提案のたびに全メモを解析しないよう保存しておく
    var tokens: [String] = []
    var theme: MemoTheme?

    init() {}

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return firstLine.isEmpty ? "新規メモ" : firstLine
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
