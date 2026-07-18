import SwiftUI
import WidgetKit

/// Younity のホーム。
/// 「ふたり」タブ = 相手の気配を大きく表示し、状態を選んでウィジェットを試せるプロダクト画面。
/// 「計測」タブ = デバイストークンと push→アプリ→ウィジェットのレイテンシを見るデバッグ画面。
struct ContentView: View {
    var body: some View {
        TabView {
            PartnerHomeView()
                .tabItem { Label("ふたり", systemImage: "heart.fill") }
            DebugView()
                .tabItem { Label("計測", systemImage: "waveform.path.ecg") }
        }
        .tint(Theme.you)
    }
}

// MARK: - ふたり（プロダクト画面）

struct PartnerHomeView: View {
    @State private var state = PresenceState(raw: SharedStore.state)
    @State private var updatedAt = SharedStore.receivedAt

    private let cols = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    heroCard
                    previewSection
                    Text("本番では、相手が状態を選ぶと、あなたのホーム画面ウィジェットに気配が届きます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("stateUpdated"))) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in refresh() }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Younity").font(.largeTitle.bold())
            Text("ふたりの気配").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            MochiBlob(color: Theme.partner, sleeping: state.isSleeping)
                .frame(width: 128, height: 118)
            HStack(spacing: 8) {
                Image(systemName: state.symbol)
                Text(state.label).font(.title2.bold())
            }
            if let updatedAt {
                Text("更新 \(updatedAt, style: .time)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("まだ気配がありません")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ウィジェットを試す").font(.headline)
            Text("状態を選ぶと、ホーム画面のウィジェットがすぐ切り替わります（プレビュー）。")
                .font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(PresenceState.allCases) { s in
                    Button {
                        pick(s)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: s.symbol).font(.title3)
                            Text(s.label).font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(
                            s == state ? Theme.you.opacity(0.22) : Color.white.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(s == state ? Theme.you : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func pick(_ s: PresenceState) {
        SharedStore.setState(s.rawValue, emotion: "happy")
        state = s
        updatedAt = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refresh() {
        state = PresenceState(raw: SharedStore.state)
        updatedAt = SharedStore.receivedAt
    }
}

// MARK: - 計測（デバッグ）

struct DebugView: View {
    @State private var token = SharedStore.token
    @State private var logs = SharedStore.logs
    @State private var state = SharedStore.state

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        NavigationStack {
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
            .navigationTitle("計測")
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
