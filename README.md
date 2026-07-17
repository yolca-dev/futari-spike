# ウィジェットPush更新スパイク 手順書

**目的**: 「相手の操作 → push → 自分の端末のウィジェット（ホーム＋ロック画面）が更新される」流れが、実際に何秒で・どんな条件で動くかを実測する。本アプリ最大の技術リスクの検証。

**構成**（Supabase不要の最小構成）:

```
Windows（このPC）                    クラウドMac              あなたのiPhone
send.ts ──APNs silent push──▶ [ビルドだけ担当] ──TestFlight──▶ アプリ＋ウィジェット
                                                              （計測ログを画面で確認）
```

---

## 0. 準備状況（2026-07-17 時点・ここまで自動セットアップ済み）

- [x] Apple Developer Program 登録
- [x] **APNsキー作成済み**: FutariPush / Key ID `Q59K8SFF93`（Sandbox & Production・Team Scoped）。`.p8` は `sender/AuthKey_Q59K8SFF93.p8` に配置済み。**再ダウンロード不可なのでこのファイルを消さないこと（バックアップ推奨）**
- [x] Team ID: `TSV38FPG86`
- [x] App Group 登録済み: `group.com.ssswataru.futarispike`
- [x] App ID 登録済み: `com.ssswataru.futarispike`（Push Notifications ＋ App Groups 割当済み）／ `com.ssswataru.futarispike.widget`（App Groups 割当済み）
- [x] App Store Connect にアプリ「**ふたりスパイク**」作成済み（内部テストグループ「内部テスト」・テスター ssswataru51@icloud.com 追加済み・自動配信ON）
- [x] **App Store Connect APIキー作成済み**: FutariBuild / Key ID `354W8MWK94`（App Manager）／ Issuer ID `d21f693e-10eb-4b81-b282-ae01de62ce43`。`.p8` は `ios/AuthKey_354W8MWK94.p8` に配置済み。**再ダウンロード不可・秘密鍵なので厳重に扱うこと**
- [x] WindowsにDeno導入済み。`sender/send.ts` は実値設定済み（TestFlight向け `SANDBOX = false`）
- [x] `project.yml` / `SharedStore.swift` / `ios/build.sh` すべて実値設定済み — **コードの書き換え作業は一切不要**
- [ ] クラウドMac（MacinCloud等）。**Xcode 15以上**が入っているプラン
- [ ] あなたのiPhone（iOS 16.1以上）に App Store の **TestFlight** アプリ

> ⚠️ **秘密鍵の扱い**: `ios/AuthKey_354W8MWK94.p8`（ビルド用）と `sender/AuthKey_Q59K8SFF93.p8`（push用）は秘密鍵。`spike/.gitignore` で除外済みだが、リポジトリやクラウドに上げないよう注意。不要になったら App Store Connect / developer.apple.com からいつでも失効(revoke)できる。

## 1. APNsキー・APIキーを作る — ✅ 完了済み（作業不要）

## 2. クラウドMacでビルド → TestFlight配信（**ターミナルに1行だけ**）

Xcodeを開く必要も、クリック操作も一切ない。署名（配布証明書・プロファイルの自動発行）とアップロードは App Store Connect APIキーで無人実行される。

1. このリポジトリの `spike/ios` フォルダを**まるごと**クラウドMacへコピー（`AuthKey_354W8MWK94.p8` を含む。Git経由 or MacinCloudのファイル転送）
2. Macのターミナルで、そのフォルダに移動して:
   ```bash
   bash build.sh
   ```
3. `▶ 5/5 … アップロード完了` が出れば成功。処理完了（5〜15分）を待つと内部テストグループへ**自動配信**される → iPhoneのTestFlightに「ふたりスパイク」が出るのでインストール

> **build.sh が中でやっていること**: ①xcodegen でプロジェクト生成 → ②xcodebuild で Release アーカイブ（`-allowProvisioningUpdates` ＋ APIキーで配布証明書・プロファイルを自動発行）→ ③ExportOptions.plist（`destination: upload`）でエクスポート即アップロード。
> **brew も xcodegen も無いプランの場合**: build.sh が対策A/B/Cを案内する。手動セットアップは下の「XcodeGenが使えない場合」を参照（その場合の署名・アップロードはXcode GUIで Archive → Distribute → 自動署名）。
> **先行確認の近道**: クラウドMacがApple Siliconなら、シミュレータでも本物のAPNs sandbox pushを受信できる（`send.ts` の `SANDBOX = true` に変えて送信）。配布なしで疎通〜おおよそのレイテンシまで確認でき、本命の実機計測（ロック放置・低電力モード）だけTestFlightで行えばよい。

**XcodeGenが使えない場合**: Xcodeで空のiOS Appプロジェクト（SwiftUI）を作り、`App/`と`Shared/`のswiftを追加 → File > New > Target > **Widget Extension**（Include Configuration Intentは外す）を追加し、生成コードを`Widget/FutariWidget.swift`の内容で置き換え＋`Shared/`を両ターゲットに所属させる → 両ターゲットに Capabilities: App Groups（同じID）、アプリ側のみ Push Notifications ＋ Background Modes > Remote notifications を追加。

## 3. 計測する（Windowsから）

1. iPhoneでアプリを起動 → 「①デバイストークン」をコピー（AirDropが無いのでメモ帳/LINE等で自分に送る）
2. ~~CONFIG書き換え~~ → **不要**（実値設定済み。TestFlight向け `SANDBOX = false` になっている）
3. 送信:
   ```
   cd futari-app/spike/sender
   deno run --allow-net --allow-read send.ts <トークン> meal happy
   ```
4. iPhoneのアプリ「③計測ログ」で **送信→アプリ** と **→ウィジェット** の秒数を確認。ホーム画面とロック画面にウィジェットを置いて、実際に表示が変わるかも目視

### 計測マトリクス（各条件で5回以上）

| 条件 | 送信→アプリ | →ウィジェット | 備考 |
|---|---|---|---|
| フォアグラウンド | | | |
| バックグラウンド（ホームに戻って1分後） | | | |
| 画面ロック中 | | | |
| ロックして30分放置後 | | | ここが本命。間引きの実態 |
| 低電力モードON | | | |
| アプリをスワイプで強制終了 | | | **仕様上pushで起きない**はず（確認） |

### 判断基準（この結果で本実装の設計を決める）

- 中央値が**数秒〜1分以内**: silent push主体の設計でOK
- **数分〜届かないことがある**: 「アプリを開いた時に必ず同期」＋「ウィジェット自身の定期更新（15分〜）」の併用設計へ
- 強制終了時に起きない問題: オンボーディングで「スワイプで消さないで」と案内するアプリが多い（Between等も同様の制約）

## 4. トラブルシュート

| 症状 | 原因 |
|---|---|
| `400 BadDeviceToken` | SANDBOX設定と実行環境の不一致（Xcode直インストール=sandbox / TestFlight=production） |
| `403 InvalidProviderToken` | Key ID / Team ID / .p8 の組み合わせ違い |
| `400 TopicDisallowed` | TOPIC（Bundle ID）違い |
| 200なのに届かない | silent pushはOSの裁量で遅延・破棄される（それ自体が計測対象）。連続送信しすぎると数を絞られる点にも注意 |
| トークンが「未取得」 | 実機か（シミュレータはApple Silicon Mac上のみ可）、Push Notifications capabilityの付け忘れ |

## 5. このスパイクの次

結果が出たら: ①計測値を `docs/モバイル移行計画.md` に記録 ②Android版（Glance＋FCM。WindowsのAndroid Studioで可能） ③Supabase Edge Functionへ`send.ts`を移植し「状態変更→自動push」に接続。
