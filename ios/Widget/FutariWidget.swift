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

// 状態→表示の対応（本実装ではアプリと共通の定義に寄せる）
func stateLabel(_ s: String) -> String {
    switch s {
    case "work": return "仕事中"
    case "meal": return "食事中"
    case "study": return "勉強中"
    case "bath": return "お風呂"
    case "out": return "おでかけ"
    case "workout": return "うんどう"
    case "sleep": return "おやすみ"
    default: return "ふつう"
    }
}

func stateSymbol(_ s: String) -> String {
    switch s {
    case "work": return "laptopcomputer"
    case "meal": return "fork.knife"
    case "study": return "book"
    case "bath": return "bathtub"
    case "out": return "figure.walk"
    case "workout": return "dumbbell"
    case "sleep": return "moon.zzz"
    default: return "face.smiling"
    }
}

/// もちの単色シルエット（ロック画面のtinted描画でも読めるグリフ）。
/// 上下にすこし潰れた卵形＋くり抜きの目 —— 本番アバターと同じ輪郭言語
struct MochiGlyph: View {
    var sleeping = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Ellipse()
                    .frame(width: w, height: w * 0.93)
                // 目はくり抜いて表現（単色でも顔に見える）
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

    var body: some View {
        switch family {
        case .accessoryInline:
            // ロック画面: 時計の横の1行
            Label(stateLabel(entry.state), systemImage: stateSymbol(entry.state))

        case .accessoryCircular:
            // ロック画面: 丸型。もちのシルエット＋状態アイコン
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    MochiGlyph(sleeping: entry.state == "sleep").frame(width: 30, height: 28)
                    Image(systemName: stateSymbol(entry.state)).font(.system(size: 10))
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            // ロック画面: 横長。シルエット＋名前・状態
            HStack(spacing: 8) {
                MochiGlyph(sleeping: entry.state == "sleep").frame(width: 30, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("おもち").font(.headline).widgetAccentable()
                    Text(stateLabel(entry.state)).font(.caption)
                    if let r = entry.receivedAt {
                        Text(r, style: .time).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

        default:
            // ホーム画面 small/medium: カラー版
            VStack(spacing: 6) {
                ZStack {
                    Ellipse()
                        .fill(Color(red: 0.66, green: 0.74, blue: 0.89)) // そら色（相手）
                        .frame(width: 74, height: 68)
                    VStack(spacing: 4) {
                        HStack(spacing: 14) {
                            Circle().fill(.black.opacity(0.75)).frame(width: 7)
                            Circle().fill(.black.opacity(0.75)).frame(width: 7)
                        }
                        Capsule().fill(.black.opacity(0.75)).frame(width: 12, height: 3)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: stateSymbol(entry.state)).font(.caption)
                    Text(stateLabel(entry.state)).font(.caption).bold()
                }
                if let r = entry.receivedAt {
                    Text("更新 \(r, style: .time)").font(.caption2).foregroundColor(.secondary)
                }
            }
            .widgetBackgroundCompat(
                LinearGradient(colors: [Color(red: 0.99, green: 0.95, blue: 0.91), Color(red: 0.96, green: 0.91, blue: 0.95)], startPoint: .top, endPoint: .bottom)
            )
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
