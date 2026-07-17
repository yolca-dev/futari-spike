#!/bin/bash
# ふたりスパイク — クラウドMac用 完全自動ビルド＆TestFlightアップロード。
# 使い方: このフォルダ（ios）に AuthKey_354W8MWK94.p8 が入った状態で
#   bash build.sh
# を実行するだけ。Xcodeを開く必要も、クリック操作も一切ない。
#
# 署名（配布証明書・プロビジョニングプロファイルの自動発行）とアップロードは
# App Store Connect APIキーで無人実行される。Apple IDでのサインインは不要。

set -euo pipefail

# ===== 設定（実値・変更不要） =====
KEY_ID="354W8MWK94"                                    # App Store Connect APIキー FutariBuild
ISSUER_ID="d21f693e-10eb-4b81-b282-ae01de62ce43"      # Issuer ID
TEAM_ID="TSV38FPG86"
SCHEME="FutariSpike"
# ===================================

cd "$(dirname "$0")"
DIR="$(pwd)"
API_KEY_PATH="$DIR/AuthKey_${KEY_ID}.p8"
BUILD="$DIR/build"

if [ ! -f "$API_KEY_PATH" ]; then
  echo "‼ APIキーが見つかりません: $API_KEY_PATH"
  echo "  AuthKey_${KEY_ID}.p8 をこのフォルダに置いてから再実行してください。"
  exit 1
fi

echo "▶ 1/5 xcodegen を確認..."
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "  xcodegen をインストール中（数分かかることがあります）..."
    brew install xcodegen
  else
    echo "‼ xcodegen も Homebrew もありません。"
    echo "  対策A: Homebrewを入れる → /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "  対策B: XcodeGenのバイナリを直接入れる → https://github.com/yonaskolb/XcodeGen/releases"
    echo "  対策C: READMEの『XcodeGenが使えない場合』でXcode手動セットアップ"
    exit 1
  fi
fi

echo "▶ 2/5 Xcodeプロジェクトを生成..."
rm -rf "$DIR/FutariSpike.xcodeproj"
xcodegen

echo "▶ 3/5 アーカイブを作成（署名は自動・APIキー使用）..."
mkdir -p "$BUILD"
xcodebuild \
  -project "$DIR/FutariSpike.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD/FutariSpike.xcarchive" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  archive

echo "▶ 4/5 エクスポート設定を作成..."
cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><true/>
</dict>
</plist>
PLIST

echo "▶ 5/5 TestFlight へアップロード..."
xcodebuild -exportArchive \
  -archivePath "$BUILD/FutariSpike.xcarchive" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" \
  -exportPath "$BUILD/export" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

echo ""
echo "======================================================================"
echo "✅ アップロード完了。"
echo "  App Store Connect 側の処理（5〜15分）が終わると、内部テストグループ"
echo "  『内部テスト』へ自動配信されます。iPhoneの TestFlight アプリに"
echo "  『ふたりスパイク』が出たらインストールしてください。"
echo "======================================================================"
