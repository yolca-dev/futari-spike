import Foundation

enum BackendError: LocalizedError {
    case notConfigured
    case message(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "接続設定が未入力です"
        case .message(let m): return m
        }
    }
}

/// Younity 本番バックエンド（Supabase Edge Functions）のクライアント。
///
/// 設定（baseURL / anonKey）が入るまでは、状態送信・端末登録は何もしない（no-op）。
/// ＝バックエンド未デプロイでも、いまのローカルプレビューの挙動を一切壊さない。
enum Backend {
    private static var d: UserDefaults { SharedStore.defaults }

    // MARK: 設定（Supabase）
    static var baseURL: String? { nonEmpty(d.string(forKey: "backendBaseURL")) } // 例: https://xxxx.supabase.co/functions/v1
    static var anonKey: String? { nonEmpty(d.string(forKey: "backendAnonKey")) }

    // MARK: ペア状態
    static var memberId: String?  { nonEmpty(d.string(forKey: "backendMemberId")) }
    static var coupleId: String?  { nonEmpty(d.string(forKey: "backendCoupleId")) }
    static var inviteCode: String? { nonEmpty(d.string(forKey: "backendInviteCode")) }

    static var isConfigured: Bool { baseURL != nil && anonKey != nil }
    static var isPaired: Bool { memberId != nil }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    static func saveConfig(baseURL: String, anonKey: String) {
        d.set(baseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "backendBaseURL")
        d.set(anonKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "backendAnonKey")
    }

    /// ペアを解除（設定は残す）
    static func unpair() {
        ["backendMemberId", "backendCoupleId", "backendInviteCode"].forEach { d.removeObject(forKey: $0) }
    }

    // MARK: 通信

    private static func post(_ path: String, _ payload: [String: Any]) async throws -> [String: Any] {
        guard let base = baseURL, let anon = anonKey, let url = URL(string: base + path) else {
            throw BackendError.notConfigured
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw BackendError.message(obj["error"] as? String ?? "HTTP \(http.statusCode)")
        }
        return obj
    }

    private static func store(_ r: [String: Any]) {
        if let m = r["memberId"] as? String { d.set(m, forKey: "backendMemberId") }
        if let c = r["coupleId"] as? String { d.set(c, forKey: "backendCoupleId") }
        if let code = r["inviteCode"] as? String { d.set(code, forKey: "backendInviteCode") }
    }

    // MARK: ペアリング

    /// カップルを作成 → 招待コードを得る
    static func createCouple(displayName: String) async throws {
        let r = try await post("/pair", ["action": "create", "displayName": displayName])
        store(r)
        registerDeviceIfPossible()
    }

    /// 招待コードで参加
    static func joinCouple(code: String, displayName: String) async throws {
        let r = try await post("/pair", ["action": "join", "code": code, "displayName": displayName])
        store(r)
        registerDeviceIfPossible()
    }

    // MARK: 端末・状態

    /// 保存済みトークンがあれば登録する
    static func registerDeviceIfPossible() {
        let token = SharedStore.token
        guard token != "（未取得）", !token.isEmpty else { return }
        registerDevice(token: token)
    }

    /// デバイストークン登録（起動時／トークン更新時）。未設定/未ペアならno-op。
    static func registerDevice(token: String) {
        guard isConfigured, let member = memberId else { return }
        Task { _ = try? await post("/register-device", ["memberId": member, "token": token, "sandbox": false]) }
    }

    /// 自分の状態を相手へ（ピッカーから fire-and-forget）。未設定/未ペアならno-op。
    static func setState(_ state: String, emotion: String) {
        guard isConfigured, let member = memberId else { return }
        Task { _ = try? await post("/set-state", ["memberId": member, "state": state, "emotion": emotion]) }
    }
}
