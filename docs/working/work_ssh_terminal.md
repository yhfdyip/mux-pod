# タスク: SSH Terminal 統合

## 概要
SSH接続後にTmuxシェルにアタッチし、リアルタイムでターミナル操作を可能にする。

## 担当エージェント
- 実装: %107 (claude)
- レビュー: %110 (gemini)

## 実装対象ファイル
- `lib/screens/terminal/terminal_screen.dart` - _connectAndAttach() 実装
- `lib/providers/ssh_provider.dart` - 接続状態管理
- `lib/providers/terminal_provider.dart` - ターミナル状態管理

## チェックリスト

- [ ] SSH接続確立 (SshClient.connect)
- [ ] シェルセッション開始 (SshClient.openShell)
- [ ] ターミナルコントローラ接続 (MuxTerminalController)
- [ ] キー入力パイプライン (UI → SSH)
- [ ] 出力パイプライン (SSH → ターミナル表示)
- [ ] Tmuxセッション一覧取得
- [ ] セッション/ウィンドウ/ペイン選択
- [ ] コミット
- [ ] 成果レポート作成

## 進捗ログ

| 時刻 | 内容 |
|------|------|
| | |
