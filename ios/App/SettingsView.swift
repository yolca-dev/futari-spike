import SwiftUI

/// 設定タブ: Supabase接続設定の入力と、カップルのペアリング（作成/参加/解除）。
/// バックエンド未デプロイでも画面は開ける（保存/通信ボタンが no-op / エラーになるだけ）。
struct SettingsView: View {
    @State private var baseURL = Backend.baseURL ?? ""
    @State private var anonKey = Backend.anonKey ?? ""
    @State private var name = "わたし"
    @State private var joinCode = ""
    @State private var status = ""
    @State private var busy = false

    @State private var configured = Backend.isConfigured
    @State private var paired = Backend.isPaired
    @State private var inviteCode = Backend.inviteCode

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                pairingSection
                if !status.isEmpty {
                    Section { Text(status).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Text("Supabaseをデプロイして、ここに Function URL と anon key を入れると本番稼働します。手順は spike/backend/README.md に。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .disabled(busy)
        }
    }

    private var connectionSection: some View {
        Section("接続設定 (Supabase)") {
            TextField("Function URL（…/functions/v1）", text: $baseURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(.caption)
            TextField("anon key", text: $anonKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(.caption)
            Button("保存") {
                Backend.saveConfig(baseURL: baseURL, anonKey: anonKey)
                configured = Backend.isConfigured
                status = configured ? "接続設定を保存しました" : "URLとanon keyを入力してください"
            }
            Label(configured ? "設定済み" : "未設定",
                  systemImage: configured ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(configured ? .green : .secondary)
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section("ペア設定") {
            if !configured {
                Text("先に接続設定を保存してください").font(.caption).foregroundStyle(.secondary)
            } else if paired {
                if let code = inviteCode {
                    HStack {
                        Text("あなたの招待コード")
                        Spacer()
                        Text(code).font(.system(.headline, design: .monospaced)).textSelection(.enabled)
                    }
                    Text("このコードを相手に伝えて『コードで参加』してもらってください。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("ペア設定済み", systemImage: "heart.fill").font(.caption).foregroundStyle(.pink)
                }
                Button("ペアを解除", role: .destructive) {
                    Backend.unpair()
                    paired = false; inviteCode = nil
                    status = "ペアを解除しました"
                }
            } else {
                TextField("あなたの表示名", text: $name)
                Button("カップルを作る（招待コードを発行）") {
                    run { try await Backend.createCouple(displayName: name) }
                }
                Divider()
                TextField("相手の招待コード", text: $joinCode)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .font(.system(.headline, design: .monospaced))
                Button("コードで参加") {
                    run { try await Backend.joinCouple(code: joinCode, displayName: name) }
                }
                .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// 非同期処理を実行し、状態と結果表示を更新する（ボタンアクションはMainActor）
    private func run(_ op: @escaping () async throws -> Void) {
        busy = true
        status = "通信中…"
        Task {
            do {
                try await op()
                paired = Backend.isPaired
                inviteCode = Backend.inviteCode
                status = paired ? "ペア設定が完了しました 🎉" : "完了しました"
            } catch {
                status = "エラー: \(error.localizedDescription)"
            }
            busy = false
        }
    }
}
