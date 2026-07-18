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
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
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
    @State private var myState = PresenceState(raw: SharedStore.myState)
    @State private var partnerName = SharedStore.partnerName
    @State private var sendMsg = ""

    private let cols = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    /// ペア済みなら「自分の状態」、未ペアなら「表示中の状態」をハイライト対象にする
    private var selected: PresenceState { Backend.isPaired ? myState : state }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if !Backend.isPaired {
                        pairingHint
                    }
                    heroCard
                    previewSection
                    if !Backend.isPaired {
                        Text("本番では、相手が状態を選ぶと、あなたのホーム画面ウィジェットに気配が届きます。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .onAppear { refresh(); fetchPartner() }
        .onReceive(NotificationCenter.default.publisher(for: .init("stateUpdated"))) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in refresh(); fetchPartner() }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Younity").font(.largeTitle.bold())
            Text("ふたりの気配").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var pairingHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
            Text("「設定」タブでペアリングすると、相手の本当の気配が届きます。いまはプレビュー中です。")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            // 2匹のシーン（左=自分オレンジ / 右=相手青紫）。アイコンと同じ世界観。
            ZStack {
                MochiBlob(color: Theme.you)
                    .frame(width: 96, height: 88)
                    .offset(x: -26)
                MochiBlob(color: Theme.partner, sleeping: state.isSleeping)
                    .frame(width: 104, height: 96)
                    .offset(x: 26)
            }
            .frame(height: 104)
            HStack(spacing: 8) {
                Image(systemName: state.symbol)
                Text("\(partnerName ?? "あいて")は「\(state.label)」").font(.title3.bold())
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
            Text(Backend.isPaired ? "あなたのいまを送る" : "ウィジェットを試す").font(.headline)
            Text(Backend.isPaired
                 ? "状態を選ぶと、相手のホーム画面ウィジェットに届きます。"
                 : "状態を選ぶと、ホーム画面のウィジェットがすぐ切り替わります（プレビュー）。")
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
                            s == selected ? Theme.you.opacity(0.22) : Color.white.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(s == selected ? Theme.you : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            if !sendMsg.isEmpty {
                Text(sendMsg).font(.caption2).foregroundStyle(Theme.you)
            }
        }
    }

    private func pick(_ s: PresenceState) {
        if Backend.isPaired {
            // ペア済み: 自分の状態を相手へ送る（自分のウィジェット＝相手表示は変えない）
            SharedStore.setMyState(s.rawValue)
            myState = s
            Backend.setState(s.rawValue, emotion: "happy")
            sendMsg = "「\(s.label)」を送りました ✓"
        } else {
            // 未ペア: プレビューとして表示中の状態を切り替え、ウィジェットを試す
            SharedStore.setState(s.rawValue, emotion: "happy")
            state = s
            updatedAt = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refresh() {
        state = PresenceState(raw: SharedStore.state)
        updatedAt = SharedStore.receivedAt
        myState = PresenceState(raw: SharedStore.myState)
        partnerName = SharedStore.partnerName
    }

    /// ペア済みなら相手の最新の名前・状態を取得して反映
    private func fetchPartner() {
        guard Backend.isPaired else { return }
        Task {
            if let st = try? await Backend.coupleStatus() {
                if let name = st.name { SharedStore.set(partnerName: name) }
                if let s = st.state { SharedStore.setState(s, emotion: st.emotion ?? "happy") }
                refresh()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
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
