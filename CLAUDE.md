# QuickDrop（仮）— ドラッグ専用ミニFinder

## このプロジェクトは何か

macOS用の常駐ミニアプリ。ショートカット（アプリ外で設定）で呼び出すと、
ファイル一覧のフローティングパネルがポップアップし、そこから任意のアプリへ
ファイルをドラッグ&ドロップして添付できる。「余計な機能のないFinder」。

## 成立条件（これが満たせなければ何を作っても無意味）

**グローバルに即座に出せるフローティングパネルが、選んだファイルを
OS標準のドラッグとして外部アプリ（Mail, Slack, ブラウザ等）に渡せること。**

サイドバー・タグ・最近の項目はすべてこの上の肉付けであり、後回し。

## 設計上の確定事項

- **App Sandbox はオフ**。自分用アプリでApp Store配布はしない。
  security-scoped bookmarks の複雑さを避ける
- パネルは `NSPanel` + `.nonactivatingPanel`。呼び出し元アプリの
  フォーカスを奪わない（Spotlight/Raycast と同じ挙動）。
  `level = .floating` でドラッグ中も最前面
- ドラッグ出しは `onDrag { NSItemProvider(contentsOf: url)! }` から開始。
  複数選択ドラッグが必要になったら AppKit の `NSDraggingSession` に落とす
- UIは SwiftUI、ウィンドウ管理だけ AppKit ブリッジ
- メニューバー常駐（`LSUIElement = YES`）、Dockアイコンなし
- ショートカット起動はアプリ側では実装しない。外部ツールから
  activate されたらパネルを表示するだけ

## プロジェクト構成の方針

- Xcode GUI に依存しない。SPM executable target + 手書き Info.plist
- ビルドは `swift build` または `xcodebuild` でCLI完結させる
- `.app` バンドル化はスクリプトで行う（Makefile か build.sh）

## マイルストーン

1. **M1（最優先）**: 固定の1フォルダの中身を一覧表示し、
   1ファイルをドラッグして Mail.app に添付できる
2. M2: パネルの nonactivating 挙動とメニューバー常駐
3. M3: サイドバー（よく使うフォルダ、UserDefaults にパス保存）
4. M4: Finderタグ（`URLResourceValues.tagNames` で読む）
5. M5: 最近使った項目（`NSMetadataQuery` + `kMDItemLastUsedDate`）
6. M6: サムネイル（`QLThumbnailGenerator`）、見た目の調整

## 実装メモ

- ファイル一覧: `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:)`
- Finderタグ: `try url.resourceValues(forKeys: [.tagNamesKey]).tagNames`
- 最近の項目: Spotlight検索。`NSMetadataQuery` の predicate に
  `kMDItemLastUsedDate` を使い、Finderの「最近の項目」相当を得る
- パネルは `canBecomeKey` をオーバーライドして検索フィールド等で
  キー入力が必要なときだけ true にする調整が必要になる可能性あり

## 検証の役割分担

ビルドエラーまではClaude Codeが回す。パネルの出方・ドラッグの手触り・
他アプリへのドロップ成否は人間（ぼく）が実機で確認して報告する。

## やらないこと

- ファイル操作（移動・削除・リネーム）。これはFinderの仕事
- App Store配布、署名・公証（必要になったら別途）
- アプリ内ショートカット設定UI
