import WidgetKit
import SwiftUI

// iOS17の containerBackground と iOS16の background を吸収するヘルパー
extension View {
    @ViewBuilder
    func widgetBackgroundCompat<B: View>(_ bg: B) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { bg }
        } else {
            background(bg)
        }
    }
}

// ホーム画面（small/medium）＋ロック画面（circular/rectangular/inline）対応のウィジェット。
// タイムラインは「pushが来たらアプリ側が reloadAllTimelines を呼ぶ」前提で、自前の定期更新は1時間ごとの保険のみ

struct Entry: TimelineEntry {
    let date: Date
    let state: String
    let emotion: String
    let receivedAt: Date?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), state: "meal", emotion: "happy", receivedAt: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 計測: タイムラインが実際に再生成された時刻を記録（アプリのログ画面が読む）
        SharedStore.markWidgetReload()
        let entry = currentEntry()
        // 保険として1時間後に自動更新（基本はpush駆動）
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
    private func currentEntry() -> Entry {
        Entry(date: Date(), state: SharedStore.state, emotion: SharedStore.emotion, receivedAt: SharedStore.receivedAt)
    }
}

/// 餅の単色シルエット（ロック画面のtinted描画でも読めるグリフ）。
struct MochiGlyph: View {
    var sleeping = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Ellipse()
                    .frame(width: w, height: w * 0.93)
                Group {
                    if sleeping {
                        Capsule().frame(width: w * 0.16, height: w * 0.05).offset(x: -w * 0.14, y: -w * 0.02)
                        Capsule().frame(width: w * 0.16, height: w * 0.05).offset(x: w * 0.14, y: -w * 0.02)
                    } else {
                        Circle().frame(width: w * 0.1).offset(x: -w * 0.14, y: -w * 0.04)
                        Circle().frame(width: w * 0.1).offset(x: w * 0.14, y: -w * 0.04)
                    }
                    Capsule().frame(width: w * 0.14, height: w * 0.05).offset(y: w * 0.12)
                }
                .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct FutariWidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) var family

    private var ps: PresenceState { PresenceState(raw: entry.state) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(ps.label, systemImage: ps.symbol)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    MochiGlyph(sleeping: ps.isSleeping).frame(width: 30, height: 28)
                    Image(systemName: ps.symbol).font(.system(size: 10))
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            HStack(spacing: 8) {
                MochiGlyph(sleeping: ps.isSleeping).frame(width: 30, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("あいての気配").font(.headline).widgetAccentable()
                    Text(ps.label).font(.caption)
                    if let r = entry.receivedAt {
                        Text(r, style: .time).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

        case .systemMedium:
            // ホーム画面（横長）: 2匹のシーン＋相手の状態
            HStack(spacing: 16) {
                ZStack {
                    MochiBlob(color: Theme.you)
                        .frame(width: 62, height: 58)
                        .offset(x: -15)
                    MochiBlob(color: Theme.partner, sleeping: ps.isSleeping)
                        .frame(width: 70, height: 64)
                        .offset(x: 15)
                }
                .frame(width: 112)
                VStack(alignment: .leading, spacing: 4) {
                    Text("あいてはいま").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: ps.symbol)
                        Text(ps.label).font(.title3.bold())
                    }
                    if let r = entry.receivedAt {
                        Text("更新 \(r, style: .time)").font(.caption2).foregroundColor(.secondary)
                    } else {
                        Text("気配待ち").font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .widgetBackgroundCompat(Theme.background)

        default:
            // ホーム画面（small）: 相手中心
            VStack(spacing: 6) {
                MochiBlob(color: Theme.partner, sleeping: ps.isSleeping)
                    .frame(width: 66, height: 60)
                HStack(spacing: 5) {
                    Image(systemName: ps.symbol).font(.caption)
                    Text(ps.label).font(.caption).bold()
                }
                if let r = entry.receivedAt {
                    Text("更新 \(r, style: .time)").font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(8)
            .widgetBackgroundCompat(Theme.background)
        }
    }
}

@main
struct FutariWidgetBundle: WidgetBundle {
    var body: some Widget {
        FutariWidget()
    }
}

struct FutariWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FutariSpikeWidget", provider: Provider()) { entry in
            FutariWidgetView(entry: entry)
        }
        .configurationDisplayName("ふたりの気配")
        .description("相手のいまの様子")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}
