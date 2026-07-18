import Foundation

/// Younity 本番バックエンド（Supabase Edge Function `set-state`）のクライアント。
///
/// 未設定のあいだは何もしない（no-op）。＝いまのローカルプレビューの挙動を一切変えない。
/// Supabase をデプロイしたら `Backend.configure(...)` を1回呼ぶだけで、状態変更が相手へ push される。
enum Backend {
    private static var d: UserDefaults { SharedStore.defaults }

    static var functionURL: String? { d.string(forKey: "backendFunctionURL") } // 例: https://xxxx.supabase.co/functions/v1/set-state
    static var anonKey: String?     { d.string(forKey: "backendAnonKey") }
    static var memberId: String?    { d.string(forKey: "backendMemberId") }

    static var isConfigured: Bool {
        !(functionURL ?? "").isEmpty && !(anonKey ?? "").isEmpty && !(memberId ?? "").isEmpty
    }

    /// 起きてからペアリング/初期設定時に1回呼ぶ。
    static func configure(functionURL: String, anonKey: String, memberId: String) {
        d.set(functionURL, forKey: "backendFunctionURL")
        d.set(anonKey, forKey: "backendAnonKey")
        d.set(memberId, forKey: "backendMemberId")
    }

    /// 自分の状態を相手へ送る。未設定なら何もしない。
    static func setState(_ state: String, emotion: String) {
        guard isConfigured,
              let urlStr = functionURL, let url = URL(string: urlStr),
              let anon = anonKey, let member = memberId,
              let body = try? JSONSerialization.data(withJSONObject: [
                  "memberId": member, "state": state, "emotion": emotion,
              ]) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
    }
}
