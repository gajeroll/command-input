# Command Input

[English](README.md)

Command Input は、Command キーの単押しで日本語入力モードを切り替える軽量な
macOS メニューバーアプリです。

- **左 Command キー**（単押し） → 英数
- **右 Command キー**（単押し） → かな

`Command-C` や `Command-Space` などの標準的なキーボードショートカットはそのまま
動作します。

## 必要環境

- **対応 OS:** macOS 14.0 Sonoma 以降
- **アーキテクチャ:** Apple silicon および Intel（リリースは Universal Binary）
- **ビルド環境（ソースからビルドする場合）:** Swift 6 および Xcode Command Line Tools

## インストール

### ビルド済みバイナリ

[Releases](https://github.com/gajeroll/command-input/releases) から最新の
`CommandInput-<version>.zip` をダウンロード・解凍し、`Command Input.app` を
`/Applications` に配置してください。

### ソースからビルド

```sh
git clone https://github.com/gajeroll/command-input.git
cd command-input
make            # build/Command Input.app をビルド（ホストアーキテクチャ）
make run        # ビルドディレクトリから実行
make install    # /Applications にインストール
```

Command Input はメニューバー常駐アプリとして動作し、Dock には表示されません。

### アンインストール

```sh
make uninstall  # /Applications/Command Input.app を削除
```

アプリを終了してゴミ箱へ移動することでもアンインストールできます。

## 権限とプライバシー

修飾キーの監視と入力切り替えイベントの送信のために、**アクセシビリティ**権限が
必要です。

- **権限の付与:** アプリ起動時にダイアログが表示されたら、**システム設定 >
  プライバシーとセキュリティ > アクセシビリティ** で Command Input を許可して
  ください。
- **入力監視（Input Monitoring）権限は不要:** セッションレベルの `CGEventTap`
  を使用するため、より広い入力監視権限は必要ありません。
- **イベントタップの動作:** タップは `listenOnly` で作成されるため、キーイベント
  を変更または破棄することはありません。ショートカットやキー長押しで誤って
  切り替わらないよう、`keyDown`、`keyUp`、`flagsChanged` を監視します。入力内容
  の保存や外部送信は行いません。
- **プライバシーマニフェスト:** `PrivacyInfo.xcprivacy` を同梱しています
  （トラッキングなし、データ収集なし、UserDefaults 使用理由: CA92.1）。

詳細なセキュリティポリシーおよび検証手順は [SECURITY.md](SECURITY.md) を参照して
ください。

## ログイン時の自動起動

macOS の `SMAppService` と内部設定で管理します。内部設定を正とみなすため、
macOS 側で登録が消えても無効化とは扱わず、再登録を試します。

### デフォルトの動作

- **インストール済みアプリ**（`/Applications` または `~/Applications`）:
  初回起動時に自動で有効化されます。
- **開発ビルド**（`build/`）: 一時パスが登録されないよう、初回の自動登録は
  行いません。メニューからの手動設定は使えます。

### 承認・修復・無効化

- **承認が必要な場合:** アプリメニューの **Open Login Items Settings** から
  ログイン項目を開き、Command Input を有効にしてください。
- **修復:** 登録が外れた場合、アプリが数回再試行し、解決しなければメニューに
  **Repair Launch at Login** を出します。
- **無効化:** アプリ内のトグルでオフにしてください。システム設定で項目を消して
  も、内部設定から復元されます。

## トラブルシューティング

- **キーを押しても切り替わらない:** **システム設定 > プライバシーとセキュリティ
  > アクセシビリティ** で Command Input が有効か確認してください。更新後や署名
  変更後は、一度オフにしてから再度オンにしてください。
- **メニューに「Repair Launch at Login」が表示される:** クリックしてログイン
  項目を再登録してください。
- **メニューに「Approve Command Input in Login Items」が表示される:**
  システム設定のログイン項目を開き、アプリを承認してください。

## 開発

コントリビューションを歓迎します。セットアップ、署名、アーキテクチャ、リリース
手順は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

```sh
make            # ホスト環境向けバイナリのビルド
make test       # Swift Testing によるテストの実行
make run        # ビルドして実行
make clean      # ビルド成果物の削除
```

## セキュリティ

イベントタップの保証と脆弱性報告は [SECURITY.md](SECURITY.md) を参照してください。

## ロードマップ

- Homebrew Cask による配布
- DMG パッケージング
- 自動アップデート

## クレジット

[iMasanari/cmd-eikana](https://github.com/iMasanari/cmd-eikana) および
[dominion525/cmd-eikana](https://github.com/dominion525/cmd-eikana) に着想を
得ています。

## ライセンス

[MIT License](LICENSE) の下で配布されています。
