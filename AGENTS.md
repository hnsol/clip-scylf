# ClipScylf — クリップボード監視ドラッグトレイ

## このプロジェクトは何か

macOS用の常駐ミニアプリ。yaziやFinderでコピーされたファイルURLを
システムクリップボードから拾い、フローティングパネルに溜める。
そこから Teams、Mail、ブラウザ等へOS標準のドラッグ&ドロップで添付する。

ファイル選択はyazi/Finder側で行う。ClipScylfは「コピー済みファイルを
外部アプリへ投げるための薄いトレイ」に徹する。

名前の由来: `Clip`（クリップボード）+ `Scylf`（shelfの古英語形）。

## 成立条件

**yazi/Finderでコピーしたファイルが即座にパネルへ表示され、
そこから外部アプリへファイル名を保ったままドラッグ&ドロップできること。**

フォルダ一覧、サイドバー、タグ、最近の項目は現在の主方向ではない。

## 設計上の確定事項

- **App Sandbox はオフ**。自分用アプリでApp Store配布はしない。
- パネルは `NSPanel` + `.nonactivatingPanel`。
  呼び出し元アプリのフォーカスを奪わない。
- `level = .floating` で前面表示する。
- UIは SwiftUI、ウィンドウ管理だけ AppKit ブリッジ。
- メニューバー常駐（`LSUIElement = YES`）、Dockアイコンなし。
- `.app` には `Resources/AppIcon.icns` を設定する。
- README等の表示用には `Resources/AppIcon.png` を使う。
- ショートカット起動はアプリ側では実装しない。
  外部ツールから activate されたらパネルを表示する。
- クリップボードは `NSPasteboard.general.changeCount` をTimerで監視する。
- ファイルURL取得は
  `readObjects(forClasses:[NSURL.self], options:[.urlReadingFileURLsOnly:true])`
  を使う。plain-textパスのフォールバックは不要。
- ドラッグ出しは `NSItemProvider` に `UTType.fileURL.identifier` を渡し、
  `suggestedName` でファイル名を保持する。

## 現在の仕様

- 起動時に既存クリップボードのファイルURLも読む。
- 新しくコピーされたファイルを先頭へ積む。
- 同一ファイルを再コピーしたら重複させず先頭へ移動する。
- 保持上限は20件。
- 通常は窓なしで監視し、ファイルURL追加時に左下ミニウィンドウを出す。
- ミニウィンドウをクリックすると通常ウィンドウへ拡大する。
- 通常ウィンドウを閉じるとミニウィンドウへ戻る。
- ミニウィンドウの閉じるボタンは非表示に戻すだけで、監視は継続する。
- メニューバーから通常ウィンドウを開ける。
- メニューバーアイコンは `archivebox.fill`。
- 複数行を選択してまとめてドラッグ&ドロップできる。
- 通常ウィンドウで全選択できる。
- 行ごとの削除ボタン、または右クリックで削除できる。
- 通常ウィンドウ上部のツールバーで全選択・全件クリアできる。

## プロジェクト構成

- Xcode GUI に依存しない。
- SPM executable target + 手書き `Info.plist`。
- ビルドは `swift build` または `./build.sh`。
- `.app` バンドル化は `build.sh` で行う。
- `build.sh` は `Info.plist`、実行ファイル、`Resources/AppIcon.icns` を
  `.app` へコピーする。
- 実機で起動する `.app` を更新する必要がある変更では、`swift build`
  だけで終えず、必ず `./build.sh` で `build/ClipScylf.app` を作り直す。
- 主実装は `Sources/QuickDrop/main.swift`。
  フォルダ名は移行途中で残っていてもよい。名称上の正はClipScylf。

## マイルストーン

1. **M1**: 固定フォルダ一覧から1ファイルをドラッグできる。
2. **M2**: nonactivatingパネルとメニューバー常駐。
3. **M3**: よく使うフォルダのサイドバー。
4. **M4**: Finderタグ一覧。
5. **M5**: クリップボード監視トレイへ方向転換。
6. **M6（現在）**: 実機フィードバックに基づくD&D安定化と見た目調整。

## 検証の役割分担

ビルドエラーまではCodexが回す。パネルの出方、ドラッグの手触り、
Teams/Mail/ブラウザへのドロップ成否は人間が実機で確認する。
UI変更や実機で起動する `.app` に反映が必要な変更では、検証時に
`swift build` だけで終えず、必ず `./build.sh` まで実行する。

## やらないこと

- ファイル操作（移動・削除・リネーム）。
- App Store配布、署名・公証。
- アプリ内ショートカット設定UI。
- アプリ内ファイルブラウザ、タグブラウザ、最近の項目一覧。
