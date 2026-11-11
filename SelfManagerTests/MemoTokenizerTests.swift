import Foundation
import Testing
@testable import SelfManager

struct MemoTokenizerTests {
    @Test func 助詞や短い語は除く() {
        #expect(!MemoTokenizer.isMeaningful("の"))
        #expect(!MemoTokenizer.isMeaningful("です"))
        #expect(!MemoTokenizer.isMeaningful("12"))
        #expect(!MemoTokenizer.isMeaningful("こと"))
        #expect(MemoTokenizer.isMeaningful("部活"))
        #expect(MemoTokenizer.isMeaningful("swift"))
    }

    @Test func 日本語の文から単語を取り出す() {
        let tokens = MemoTokenizer.tokens(from: "明日の部活の練習メニューを考える")
        #expect(!tokens.isEmpty)
        #expect(!tokens.contains("の"))
        #expect(!tokens.contains("を"))
    }

    @Test func 重複単語の多い順に並べる() {
        let scores = MemoTokenizer.rank(["部活", "練習", "大会"], against: [
            (id: "A", tokens: ["部活", "練習", "顧問"]),
            (id: "B", tokens: ["課題", "レポート"]),
            (id: "C", tokens: ["大会"]),
        ])
        #expect(scores == [MemoTokenizer.Score(id: "A", count: 2), MemoTokenizer.Score(id: "C", count: 1)])
    }
}
