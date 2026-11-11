import Foundation
import SwiftData

/// カレンダーには入れない習慣的な予定（学校・睡眠など）。空き時間の提案で「埋まっている時間」として使う
@Model
final class HabitSchedule {
    var id: UUID = UUID()
    var name: String = ""
    /// 1=日 … 7=土
    var weekdays: [Int] = []
    /// 0時からの分数（例: 8:30 → 510）
    var startMinutes: Int = 0
    /// 開始より小さい値なら翌日の時刻として扱う（例: 睡眠 23:00〜7:00）
    var endMinutes: Int = 0
    var validFrom: Date?
    var validTo: Date?
    /// この日だけ予定なし（その日の0時で保存）
    var exceptionDates: [Date] = []
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    init(name: String) {
        self.name = name
    }
}
