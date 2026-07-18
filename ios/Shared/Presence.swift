import SwiftUI

// アプリ本体とウィジェットで共有する「状態」の定義・配色・マスコット描画。
// Shared/ にあるのでどちらのターゲットからも参照できる。

// MARK: - 状態

/// 相手（や自分）の「いまの様子」。push の "state" 文字列と1:1で対応する。
enum PresenceState: String, CaseIterable, Identifiable {
    case awake, work, study, meal, bath, out, workout, sleep

    var id: String { rawValue }

    /// 未知の文字列は .awake に丸める（クラッシュさせない）
    init(raw: String?) {
        self = PresenceState(rawValue: raw ?? "") ?? .awake
    }

    var label: String {
        switch self {
        case .awake:   return "ふつう"
        case .work:    return "仕事中"
        case .study:   return "勉強中"
        case .meal:    return "ごはん"
        case .bath:    return "おふろ"
        case .out:     return "おでかけ"
        case .workout: return "うんどう"
        case .sleep:   return "おやすみ"
        }
    }

    /// SF Symbol 名（存在しない場合でも描画が空になるだけでクラッシュはしない）
    var symbol: String {
        switch self {
        case .awake:   return "face.smiling"
        case .work:    return "laptopcomputer"
        case .study:   return "book.fill"
        case .meal:    return "fork.knife"
        case .bath:    return "shower.fill"
        case .out:     return "figure.walk"
        case .workout: return "dumbbell.fill"
        case .sleep:   return "moon.zzz.fill"
        }
    }

    var emoji: String {
        switch self {
        case .awake:   return "☺️"
        case .work:    return "💻"
        case .study:   return "📖"
        case .meal:    return "🍚"
        case .bath:    return "🛁"
        case .out:     return "🚶"
        case .workout: return "🏃"
        case .sleep:   return "😴"
        }
    }

    var isSleeping: Bool { self == .sleep }
}

// MARK: - 配色（アイコンの2匹に合わせる）

enum Theme {
    static let you     = Color(red: 0.98, green: 0.62, blue: 0.40) // オレンジ（自分）
    static let partner = Color(red: 0.55, green: 0.62, blue: 0.90) // 青紫（相手）
    static let bgTop    = Color(red: 0.99, green: 0.96, blue: 0.92)
    static let bgBottom = Color(red: 0.97, green: 0.92, blue: 0.95)

    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - マスコット（餅ブロブ）

/// 色付きの餅マスコット。アプリ・ウィジェット共通。フレームいっぱいに描画される。
struct MochiBlob: View {
    var color: Color
    var sleeping: Bool = false
    var eyeColor: Color = Color(white: 0.15)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // からだ
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.92), color],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.height)

                // ほっぺ
                HStack(spacing: s * 0.40) {
                    cheek(s)
                    cheek(s)
                }
                .offset(y: s * 0.10)

                // 目
                HStack(spacing: s * 0.30) {
                    eye(s)
                    eye(s)
                }
                .offset(y: -s * 0.03)

                // くち（ちいさな笑み）
                Capsule()
                    .fill(eyeColor.opacity(0.8))
                    .frame(width: s * 0.11, height: s * 0.035)
                    .offset(y: s * 0.15)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func cheek(_ s: CGFloat) -> some View {
        Circle().fill(Color.pink.opacity(0.25)).frame(width: s * 0.15, height: s * 0.15)
    }

    @ViewBuilder
    private func eye(_ s: CGFloat) -> some View {
        if sleeping {
            Capsule().fill(eyeColor).frame(width: s * 0.13, height: s * 0.04)
        } else {
            Circle().fill(eyeColor).frame(width: s * 0.10, height: s * 0.10)
        }
    }
}
