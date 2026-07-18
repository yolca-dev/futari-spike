import Foundation

/// アプリ本体とウィジェットが共有するストレージ（App Group）。
/// App Group ID は Developer Portal に登録済み（設定済み・書き換え不要）
enum SharedStore {
    static let appGroupID = "group.com.ssswataru.futarispike"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - 状態（ウィジェットが表示する内容）

    static func update(state: String, emotion: String, receivedAt: Date, sentAtMs: Double?) {
        let d = defaults
        d.set(state, forKey: "state")
        d.set(emotion, forKey: "emotion")
        d.set(receivedAt.timeIntervalSince1970, forKey: "receivedAt")
        if let s = sentAtMs { d.set(s / 1000.0, forKey: "sentAt") }
        appendLog(sentAtMs: sentAtMs, receivedAt: receivedAt)
    }

    /// プレビュー用: 計測ログを残さず、表示状態だけを更新する（アプリのピッカーから使う）
    static func setState(_ state: String, emotion: String = "happy") {
        let d = defaults
        d.set(state, forKey: "state")
        d.set(emotion, forKey: "emotion")
        d.set(Date().timeIntervalSince1970, forKey: "receivedAt")
    }

    static var state: String { defaults.string(forKey: "state") ?? "awake" }
    static var emotion: String { defaults.string(forKey: "emotion") ?? "happy" }
    static var receivedAt: Date? {
        let t = defaults.double(forKey: "receivedAt")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    // MARK: - デバイストークン

    static func set(token: String) { defaults.set(token, forKey: "deviceToken") }
    static var token: String { defaults.string(forKey: "deviceToken") ?? "（未取得）" }

    // MARK: - 計測ログ
    // 1行 = "sentAt,receivedAt,widgetReloadedAt"（epoch秒。未計測は0）
    // アプリのログ画面が sent→received（push到達）と received→widget（再描画）を算出する

    static func appendLog(sentAtMs: Double?, receivedAt: Date) {
        var logs = defaults.stringArray(forKey: "logs") ?? []
        let sent = (sentAtMs ?? 0) / 1000.0
        logs.append("\(sent),\(receivedAt.timeIntervalSince1970),0")
        if logs.count > 100 { logs.removeFirst(logs.count - 100) }
        defaults.set(logs, forKey: "logs")
    }

    /// ウィジェット側のタイムライン生成時に呼ぶ（最後のログ行に widget 時刻を書き込む）
    static func markWidgetReload(_ date: Date = Date()) {
        var logs = defaults.stringArray(forKey: "logs") ?? []
        defaults.set(date.timeIntervalSince1970, forKey: "lastWidgetReload")
        guard let last = logs.last else { return }
        var parts = last.split(separator: ",").map(String.init)
        // 直近(30秒以内)のpush受信ログにだけ「ウィジェット更新時刻」を記録する。
        // プレビュー操作や1時間ごとの保険リロードで古いログを汚さないためのガード。
        if parts.count == 3, parts[2] == "0",
           let received = Double(parts[1]), date.timeIntervalSince1970 - received < 30 {
            parts[2] = "\(date.timeIntervalSince1970)"
            logs[logs.count - 1] = parts.joined(separator: ",")
            defaults.set(logs, forKey: "logs")
        }
    }

    static var logs: [(sent: Date?, received: Date, widget: Date?)] {
        (defaults.stringArray(forKey: "logs") ?? []).compactMap { line in
            let p = line.split(separator: ",").compactMap { Double($0) }
            guard p.count == 3 else { return nil }
            return (
                sent: p[0] > 0 ? Date(timeIntervalSince1970: p[0]) : nil,
                received: Date(timeIntervalSince1970: p[1]),
                widget: p[2] > 0 ? Date(timeIntervalSince1970: p[2]) : nil
            )
        }
    }

    static func clearLogs() { defaults.set([String](), forKey: "logs") }
}
