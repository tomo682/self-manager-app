# 自己管理アプリ（SelfManager）

iPhone 13 Pro（iOS 26）で自分だけが使う、To do・カレンダー・メモのアプリです。
Swift / SwiftUI / SwiftData / WidgetKit / EventKit で作っています。

## 機能

### To do
- テーマ（仕事・課題・部活など）を自分で作成。色・並び替え・名前変更
- To do：タイトル・期限・メモ。期限切れは赤で表示
- 習慣To do：「毎週◯曜日に表示 → ◯曜日が期限」「毎月◯日に表示 → ◯日が期限」
  - 期限までに達成しなかった回は、自動で「未達成」として記録
- ○ボタンで達成 → テーマごとの「達成・未達成の記録」に移る（右スワイプで戻せる）
- **いつやる？**：所要時間を入れると、カレンダーの予定と習慣的な予定（学校・睡眠など）を避けて、別々の日から空き時間を3つ提案。選んだ枠は標準カレンダーに登録

### ウィジェット
- ホーム画面にTo doウィジェット（小・中・大）を置ける。ウィジェットごとにテーマを選ぶ
- 未達成のTo doを期限が近い順に表示し、○ボタンで達成にできる

### カレンダー
- iPhone標準カレンダーの予定を月表示で見て、追加・編集・削除できる
- カテゴリ（遊び・部活・学校など）は標準カレンダーの「カレンダー」として作るので、標準アプリでも同じ色で表示される
- 繰り返し（毎日・毎週・毎月・毎年）。誕生日などは「イベント（終日・毎年）」で登録

### メモ
- テーマ（ファイル）ごとにメモを作成。⭐️でお気に入り
- **テーマ候補**：メモの単語と各テーマのメモの単語の重複数を数えて、候補を多い順に表示
- **データ整理**：30日以上開いていないメモ（⭐️以外）を一覧にして、選んで削除

---

## Mac でのビルド手順

### 初回だけ

1. Xcode（最新版）を App Store からインストールして、一度起動しておく
2. Homebrew で XcodeGen を入れる
   ```sh
   brew install xcodegen
   ```
3. このリポジトリを Mac に持ってくる（GitHub 経由など）
   ```sh
   git clone <リポジトリのURL>
   cd self-manager-app
   ```
4. Xcode プロジェクトを生成して開く
   ```sh
   xcodegen generate
   open SelfManager.xcodeproj
   ```
5. 署名の設定（**SelfManager** と **SelfManagerWidget** の両方）
   - ターゲットを選択 →「Signing & Capabilities」→ Team に自分の Apple Developer アカウントを選ぶ
   - 毎回選ぶのが面倒なら、`project.yml` の `DEVELOPMENT_TEAM: ""` に Team ID を書いておく
   - 「バンドルIDが使えない」と出た場合は、`com.tomo1` を自分専用の文字列に変える。変える場所は `project.yml` の冒頭コメントを参照
6. iPhone を USB でつなぐ
   - iPhone 側で「設定 → プライバシーとセキュリティ → デベロッパモード」をオンにする（初回のみ。再起動あり）
7. Xcode 上部で実行先を自分の iPhone にして ▶︎（⌘R）

### 2回目以降（コードを更新したとき）

```sh
git pull
xcodegen generate   # ファイルを追加・削除したときは必須
```
そのあと Xcode で ⌘R。

### テスト

コミットの前に、Xcode で **⌘U**（または下のコマンド）を実行してテストを通してください。

```sh
xcodebuild test -scheme SelfManager -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

テストの対象は、習慣To doの回の作り方・空き時間の探し方・メモの単語分割と重複数の計算です。

### エラーが出たら

Xcode のエラー（赤いメッセージ）をコピーして Claude Code に貼ってください。

---

## 構成

```
project.yml           XcodeGen の定義（アプリ / ウィジェット / テスト）
SelfManager/
  App/                起動とタブ
  Shared/             アプリとウィジェットで共有（モデル・DB・習慣To doの処理・ウィジェットのボタン）
  Features/
    Todo/             テーマ・To do・習慣To do・記録
    Scheduling/       空き時間の提案・習慣的な予定
    Calendar/         カレンダー（EventKit）
    Memo/             メモ・テーマ候補・データ整理
    Settings/         設定
SelfManagerWidget/    To doウィジェット
SelfManagerTests/     ユニットテスト（Swift Testing）
```

- データは App Group（`group.com.tomo1.selfmanager.shared`）内の SwiftData に保存し、アプリとウィジェットで共有しています。iPhone の中だけに保存され、iCloud には送りません
- カレンダーの予定はアプリには保存せず、標準カレンダーを直接読み書きしています
