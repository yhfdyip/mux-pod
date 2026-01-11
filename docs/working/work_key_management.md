# タスク: SSH鍵管理

## 概要
SSH鍵の生成（Ed25519/RSA）とインポート機能を実装する。

## 担当エージェント
- 実装: %108 (claude)
- レビュー: %110 (gemini)

## 実装対象ファイル
- `lib/screens/keys/key_generate_screen.dart` - 鍵生成ロジック
- `lib/screens/keys/key_import_screen.dart` - 鍵インポートロジック
- `lib/services/keychain/key_generator.dart` - 鍵生成サービス（新規）
- `pubspec.yaml` - 必要なパッケージ追加

## 必要パッケージ
- `pointycastle` または `cryptography` - 鍵生成
- `file_picker` - ファイル選択

## チェックリスト

- [ ] 鍵生成パッケージ選定・追加
- [ ] Ed25519鍵生成実装
- [ ] RSA鍵生成実装（2048/4096ビット）
- [ ] 鍵のSecureStorage保存
- [ ] file_pickerパッケージ追加
- [ ] PEMファイル読み込み・パース
- [ ] 鍵インポート・保存
- [ ] コミット
- [ ] 成果レポート作成

## 進捗ログ

| 時刻 | 内容 |
|------|------|
| | |
