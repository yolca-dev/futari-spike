// APNs silent push 送信スクリプト（Deno製・Windowsで動く）。
// Supabaseなしで計測できる最小構成。本実装ではこのままSupabase Edge Functionに移植する。
//
// 準備:
//   1. https://deno.land からDenoをインストール（winget install DenoLand.Deno）
//   2. developer.apple.com → Certificates, Identifiers & Profiles → Keys →
//      「+」→ Apple Push Notifications service (APNs) にチェック → 作成し .p8 をダウンロード
//   3. このフォルダに AuthKey_XXXXXXXXXX.p8 を置き、下の CONFIG を書き換える
//
// 使い方:
//   deno run --allow-net --allow-read send.ts <デバイストークン> [state] [emotion]
//   例: deno run --allow-net --allow-read send.ts abc123... meal happy
//
// 何度も送ってレイテンシの分布を見ること（1回では傾向が分からない）

import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// ====== CONFIG（実値設定済み） ======
const KEY_ID = "Q59K8SFF93";                  // APNsキー FutariPush のキーID
const TEAM_ID = "TSV38FPG86";                 // Team ID
const TOPIC = "com.ssswataru.futarispike";    // アプリの Bundle ID
const P8_PATH = "./AuthKey_Q59K8SFF93.p8";    // このフォルダに配置済み
const SANDBOX = false;                        // TestFlight配布=false / Xcode直インストールで試すときだけ true
// ===========================================

const [token, state = "meal", emotion = "happy"] = Deno.args;
if (!token) {
  console.error("使い方: deno run --allow-net --allow-read send.ts <デバイストークン> [state] [emotion]");
  Deno.exit(1);
}

// .p8 (PKCS#8 PEM) を WebCrypto の署名鍵に変換
const pem = await Deno.readTextFile(P8_PATH);
const der = Uint8Array.from(
  atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "")),
  (c) => c.charCodeAt(0),
);
const key = await crypto.subtle.importKey(
  "pkcs8", der,
  { name: "ECDSA", namedCurve: "P-256" },
  false, ["sign"],
);

const jwt = await create(
  { alg: "ES256", kid: KEY_ID },
  { iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) },
  key,
);

const host = SANDBOX ? "api.sandbox.push.apple.com" : "api.push.apple.com";
const sentAt = Date.now();

const res = await fetch(`https://${host}/3/device/${token}`, {
  method: "POST",
  headers: {
    authorization: `bearer ${jwt}`,
    "apns-topic": TOPIC,
    "apns-push-type": "background",
    "apns-priority": "5",       // silent pushは5固定（10にすると配送拒否される）
    "apns-expiration": "0",
  },
  body: JSON.stringify({
    aps: { "content-available": 1 },
    state,
    emotion,
    sentAt, // アプリ側がこれと受信時刻の差でレイテンシを計測する
  }),
});

console.log(`HTTP ${res.status} ${res.status === 200 ? "OK" : ""}`);
if (res.status !== 200) {
  console.log(await res.text());
  console.log("ヒント: 400 BadDeviceToken は SANDBOX 設定と実行環境（Xcodeビルド/TestFlight）の不一致が典型");
} else {
  console.log(`送信完了 state=${state} emotion=${emotion} sentAt=${new Date(sentAt).toLocaleTimeString()}`);
  console.log("端末のアプリを開いて「計測ログ」を確認（silent pushはOS判断で遅延・間引きされることがある）");
}
