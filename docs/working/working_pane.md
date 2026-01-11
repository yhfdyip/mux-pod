# Working Panes - 並行開発

| 役割 | ターミナル | ID | エージェント | worktree | 状態 |
|------|-----------|-----|-------------|----------|------|
| SSH/Terminal統合 | tmux | %115 | claude | ssh-integration | active |
| SSH鍵管理 | tmux | %116 | claude | key-impl | active |
| 設定/通知 | tmux | %117 | claude | settings-impl | active |

## Worktree情報

| ブランチ | パス | 担当機能 |
|----------|------|----------|
| (detached→speckit決定) | worktree/ssh-integration | SSH接続→Tmuxアタッチ、キー送信 |
| (detached→speckit決定) | worktree/key-impl | SSH鍵生成、鍵インポート |
| (detached→speckit決定) | worktree/settings-impl | 設定保存、通知ルール保存 |

## 作業分担

### %115 - SSH/Terminal担当
- terminal_screen.dart: SSH接続してtmuxにアタッチ
- terminal_screen.dart: SSH経由でキーを送信
- ssh_provider.dart と terminal_provider.dart の統合

### %116 - 鍵管理担当
- key_generate_screen.dart: 鍵を生成
- key_import_screen.dart: ファイルピッカーで秘密鍵選択
- key_import_screen.dart: 鍵をインポート
- keys_screen.dart: 画面遷移

### %117 - 設定担当
- notification_rules_screen.dart: ルールを保存
- settings_screen.dart: 各種ダイアログと設定保存
