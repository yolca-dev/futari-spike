import SwiftUI

/// 計測用の画面。デバイストークンのコピーと、push→アプリ→ウィジェットのレイテンシログを表示する。
/// クラウドMacではXcodeコンソールを見続けられないため、端末上でログを読める作りにしている
struct ContentView: View {
    @State private var token = SharedStore.token
    @State private var logs = SharedStore.logs
    @State private var state = SharedStore.state

    let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        NavigationView {
            List {
                Section("① デバイストークン（送信スクリプトに渡す）") {
                    Text(token)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                    Button("トークンをコピー") {
                        UIPasteboard.general.string = token
                    }
                }

                Section("② いまの状態（pushで更新される）") {
                    HStack {
                        Text("state: \(state)")
                        Spacer()
                        if let r = SharedStore.receivedAt {
                            Text(timeFmt.string(from: r)).foregroundColor(.secondary)
                        }
                    }
                }

                Section("③ 計測ログ（新しい順）") {
                    if logs.isEmpty {
                        Text("まだpushを受信していません").foregroundColor(.secondary)
                    }
                    ForEach(Array(logs.reversed().enumerated()), id: \.offset) { _, log in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("受信 \(timeFmt.string(from: log.received))").font(.caption)
                            HStack(spacing: 12) {
                                if let s = log.sent {
                                    let d = log.received.timeIntervalSince(s)
                                    Text("送信→アプリ: \(String(format: "%.2f", d))秒")
                                        .foregroundColor(d < 5 ? .green : (d < 60 ? .orange : .red))
                                } else {
                                    Text("送信時刻なし")
                                }
                                if let w = log.widget {
                                    let d2 = w.timeIntervalSince(log.received)
                                    Text("→ウィジェット: +\(String(format: "%.2f", d2))秒")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("→ウィジェット: 未更新").foregroundColor(.orange)
                                }
                            }
                            .font(.caption2)
                        }
                    }
                    Button("ログをクリア", role: .destructive) {
                        SharedStore.clearLogs()
                        logs = SharedStore.logs
                    }
                }

                Section("メモ") {
                    Text("計測条件を変えて比較する: フォアグラウンド / バックグラウンド / 画面ロック中 / アプリをスワイプで強制終了（→pushでは起きない仕様） / 低電力モードON")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Younity")
            .refreshable { reload() }
            .onReceive(NotificationCenter.default.publisher(for: .init("tokenUpdated"))) { _ in reload() }
            .onReceive(NotificationCenter.default.publisher(for: .init("stateUpdated"))) { _ in reload() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in reload() }
        }
    }

    private func reload() {
        token = SharedStore.token
        logs = SharedStore.logs
        state = SharedStore.state
    }
}
