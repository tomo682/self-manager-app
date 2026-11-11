import Foundation

/// アプリ本体とウィジェットでデータを共有するための App Group
enum AppGroup {
    /// project.yml の com.apple.security.application-groups と同じ値にすること
    static let identifier = "group.com.tomo1.selfmanager.shared"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// ウィジェットでデータを変更したときに更新する値（アプリ側で再読み込みの判定に使う）
    static let widgetChangeKey = "widgetChangeToken"

    static func markChangedByWidget() {
        defaults.set(Date().timeIntervalSince1970, forKey: widgetChangeKey)
    }

    static var widgetChangeToken: Double {
        defaults.double(forKey: widgetChangeKey)
    }
}

/// アプリの設定値のキー
enum AppSettings {
    /// 期限のないTo doで空き時間を探す日数
    static let noDeadlineSearchDaysKey = "noDeadlineSearchDays"
    static let defaultNoDeadlineSearchDays = 14

    /// 提案した予定を登録するカレンダー
    static let taskCalendarIdentifierKey = "taskCalendarIdentifier"

    /// データ整理で「開いていない」とみなす日数
    static let memoCleanupDays = 30
}
