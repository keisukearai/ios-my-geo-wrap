# MyGeoWarp

A generative art Live Photo wallpaper app for iPhone.

## Overview

GeoWarp transforms your iPhone into a living canvas of geometric art. Hundreds of particles flow through 6 animation modes with 21 unique shape types. Adjust WARP, CHAOS, and TEMPO sliders to dial in the perfect look, then save it as a Live Photo wallpaper.

## Features

- **6 Animation Modes** — Tunnel, Vortex, Wave, Helix, Burst, Blend
- **21 Shape Types** — Polygons, stars, circles, rings, cross
- **WARP** — Morphs between animation modes
- **CHAOS** — Adds turbulence to particle motion
- **TEMPO** — Controls overall animation speed
- **Color Style** — Metallic cool tones to classic warm hues
- **Live Photo Export** — Save any moment as a Live Photo wallpaper

## Requirements

- Xcode 16 or later
- iOS 17 or later
- Swift 5.9+

---

## App Store 申請手順

### 前提情報

| 項目 | 値 |
|------|-----|
| Bundle ID | `com.keisukearai.MyGeoWarp` |
| Team ID | `HFZSU3MJLR` |
| Apple ID | `araiautocom3@gmail.com` |
| ASC Key ID | `6W3CF67B68` |
| ASC Issuer ID | `2963ded3-07d2-4191-88ff-78338ebcb50e` |

---

## 初回セットアップ（一度だけ実施）

### 1. Bundle ID の登録（手動）

1. [Apple Developer Portal](https://developer.apple.com) → Certificates, Identifiers & Profiles → **Identifiers**
2. **「+」** → App IDs → App
3. Description: `MyGeoWarp`、Bundle ID（Explicit）: `com.keisukearai.MyGeoWarp`
4. **Register**

### 2. アプリを App Store Connect に作成（手動）

1. [App Store Connect](https://appstoreconnect.apple.com) → マイ App → **「+」→「新規 App」**
2. 以下を入力して「作成」

| 項目 | 値 |
|------|-----|
| プラットフォーム | iOS |
| 名前 | GeoWarp |
| プライマリ言語 | English |
| バンドル ID | `com.keisukearai.MyGeoWarp` |
| SKU | `mygeowarp` |

### 3. Fastlane のインストール（自動）

```bash
cd /Users/keisukearai/workspace/ios/MyGeoWarp
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

bundle config set path 'vendor/bundle'
bundle install
```

### 4. スクリーンショットの配置（手動）

キャプチャ画像を以下に配置：

```
fastlane/screenshots/en-US/   ← 英語用
fastlane/screenshots/ja/      ← 日本語用
```

**必要なサイズ（最低限）:**
- 6.5" iPhone: 1242 × 2688 px（必須）
- 5.5" iPhone: 1242 × 2208 px（必須）

### 5. メタデータのアップロード（自動）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane upload_metadata --env local
bundle exec fastlane upload_screenshots --env local
```

---

## TestFlight へのアップロード（自動）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane beta --env local
```

---

## App Store 申請（自動）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# フルリリース（ビルド〜バイナリアップロードまで）
bundle exec fastlane release --env local

# 審査提出のみ（バイナリ提出済みの場合）
bundle exec fastlane submit --env local
```

**`release` で自動で行われること:**
1. 無料価格・配信地域の設定
2. ビルド・アーカイブ・エクスポート
3. App Store Connect にバイナリをアップロード
4. 年齢レーティング 4+ を設定
5. 審査提出

---

## 環境変数（`fastlane/.env.local` — git 管理外）

```
ASC_KEY_ID=6W3CF67B68
ASC_ISSUER_ID=2963ded3-07d2-4191-88ff-78338ebcb50e
ASC_KEY_FILEPATH=/Users/keisukearai/Downloads/AuthKey_6W3CF67B68.p8
MATCH_PASSWORD=mygeowarp2024
MATCH_GIT_URL=git@github.com:keisukearai/ios-certificates.git
APPLE_ID=araiautocom3@gmail.com
TEAM_ID=HFZSU3MJLR
REVIEW_PHONE=+819042907348
REVIEW_EMAIL=araiautocom@gmail.com
```

---

## Fastlane レーン一覧

| コマンド | 内容 |
|----------|------|
| `fastlane upload_metadata --env local` | 説明文・キーワード等をアップロード |
| `fastlane upload_screenshots --env local` | スクリーンショットをアップロード |
| `fastlane beta --env local` | ビルド → TestFlight アップロード |
| `fastlane release --env local` | ビルド → App Store バイナリアップロード → 審査提出 |
| `fastlane submit --env local` | 審査提出のみ（バイナリ提出済みの場合） |

---

## トラブルシューティング

### Ruby バージョンエラー
システムの Ruby（macOS 標準）は 2.6 系で古すぎます。必ず Homebrew の Ruby を使うこと：
```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

### アプリアイコンのアルファチャンネルエラー
App Store はアイコンに透明度を許可しません。以下で除去できます：
```bash
sips -s format jpeg -s formatOptions 100 AppIcon.png --out /tmp/tmp.jpg
sips -s format png /tmp/tmp.jpg --out AppIcon.png
```

### プロビジョニングプロファイルが見つからない
`build_app` に `export_xcargs: "-allowProvisioningUpdates"` を追加し、Xcode に自動生成させます（Fastfile 設定済み）。
