import Foundation
import NaturalLanguage

/// メモの単語分割と、テーマとの重複単語数の計算
enum MemoTokenizer {
    /// よく出るが意味の薄い語（仕分けの判断に使わない）
    static let stopWords: Set<String> = [
        "する", "した", "して", "します", "しない", "ある", "あり", "いる", "いた", "なる", "なった",
        "こと", "もの", "これ", "それ", "あれ", "どれ", "この", "その", "あの", "ここ", "そこ",
        "です", "ます", "でした", "ました", "ください", "よう", "ため", "とき", "など", "まで", "から",
        "けど", "でも", "また", "そして", "ので", "のに", "ない", "なく", "られる", "れる",
        "the", "and", "for", "with", "this", "that", "are", "was", "you", "not", "but",
    ]

    /// テキストから単語を取り出す（重複なし・並べ替え済み）
    static func tokens(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        tokenizer.setLanguage(recognizer.dominantLanguage ?? .japanese)

        var words = Set<String>()
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols))
            if isMeaningful(word) {
                words.insert(word)
            }
            return true
        }
        return words.sorted()
    }

    /// 仕分けに使う単語かどうか
    static func isMeaningful(_ word: String) -> Bool {
        guard word.count >= 2 else { return false }
        if word.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isSymbol }) { return false }
        if stopWords.contains(word) { return false }
        // 2文字以下のひらがなだけの語は助詞・助動詞のことが多いので除く
        if word.count <= 2 && word.unicodeScalars.allSatisfy({ (0x3040...0x309F).contains($0.value) }) {
            return false
        }
        return true
    }

    struct Score<ID: Hashable>: Equatable {
        let id: ID
        let count: Int
    }

    /// 各グループ（テーマ）と何語重複しているかを数え、多い順に返す（0語は除く）
    static func rank<ID: Hashable>(_ tokens: Set<String>, against groups: [(id: ID, tokens: Set<String>)]) -> [Score<ID>] {
        groups
            .map { Score(id: $0.id, count: tokens.intersection($0.tokens).count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
}
