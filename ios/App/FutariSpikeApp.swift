import SwiftUI
import WidgetKit

/// ウィジェットPush更新スパイクのアプリ本体。
/// silent push（content-available: 1）を受けて App Group に状態を書き、
/// WidgetCenter.reloadAllTimelines() を呼ぶ —— この一連のレイテンシを計測する
@main
struct FutariSpikeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // silent pushの受信だけなら通知許可ダイアログは不要（バナー表示しないため）
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        SharedStore.set(token: token)
        Backend.registerDevice(token: token) // 本番設定＆ペア済みなら相手に届くよう登録（未設定ならno-op）
        NotificationCenter.default.post(name: .init("tokenUpdated"), object: nil)
        print("APNs device token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SharedStore.set(token: "登録失敗: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .init("tokenUpdated"), object: nil)
    }

    /// silent push の受け口。アプリがバックグラウンド／サスペンド中でも起こされる
    /// （ユーザーが強制終了した場合は起こされない —— これも計測対象の挙動）
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let receivedAt = Date()
        let state = userInfo["state"] as? String ?? "awake"
        let emotion = userInfo["emotion"] as? String ?? "happy"
        let sentAtMs = userInfo["sentAt"] as? Double

        SharedStore.update(state: state, emotion: emotion, receivedAt: receivedAt, sentAtMs: sentAtMs)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .init("stateUpdated"), object: nil)

        completionHandler(.newData)
    }
}
