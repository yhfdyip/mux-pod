# タスク: MuxPod Flutter移行

## 概要
React Native/ExpoアプリをFlutterに移行する。
dartssh2 + xterm.dart を使用したSSH/tmux操作アプリを構築。

## 担当エージェント
| 役割 | ペインID | エージェント | 状態 |
|------|----------|-------------|------|
| 実装1 (speckit) | %107 | claude | standby |
| 実装2 (Flutter初期化) | %108 | claude | standby |
| レビュー | %109 | claude | standby |

## チェックリスト

### Phase 1: 仕様・計画策定
- [ ] speckit.specify - Flutter移行仕様の策定
- [ ] speckit.plan - 移行計画の作成
- [ ] speckit.tasks - タスク分解

### Phase 2: 基盤構築
- [ ] Flutterプロジェクト作成 (flutter_muxpod/)
- [ ] 依存パッケージ追加 (dartssh2, xterm.dart, riverpod, etc.)
- [ ] ディレクトリ構造構築

### Phase 3: コア機能実装
- [ ] SSH接続サービス (dartssh2)
- [ ] ターミナルUI (xterm.dart)
- [ ] tmux操作サービス
- [ ] 接続管理（状態管理）

### Phase 4: UI移植
- [ ] 接続リスト画面
- [ ] 接続編集画面
- [ ] セッション/ウィンドウ/ペイン選択画面
- [ ] ターミナル画面
- [ ] 設定画面

### Phase 5: 追加機能
- [ ] SSH鍵管理 (flutter_secure_storage)
- [ ] 通知ルール
- [ ] 折りたたみデバイス対応

### Phase 6: テスト・完了
- [ ] レビュー完了
- [ ] テスト実行
- [ ] コミット

## 進捗ログ

| 時刻 | 内容 |
|------|------|
| 2026-01-11 02:00 | 移行作業開始 |
| | |
