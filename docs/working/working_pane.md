# Working Panes - 並行開発

| 役割 | ターミナル | ID | エージェント | worktree | 状態 |
|------|-----------|-----|-------------|----------|------|
| SSH/Terminal実装 | tmux | %112 | claude | worktree/ssh-terminal | active |
| 鍵管理実装 | tmux | %113 | claude | worktree/key-management | active |
| 設定実装 | tmux | %114 | claude | worktree/settings | active |
| テスト/検証 | tmux | %110 | gemini | (main) | standby |

## Worktree情報

| ブランチ | パス | 担当機能 |
|----------|------|----------|
| feature/ssh-terminal | worktree/ssh-terminal | SSH接続→Tmuxアタッチ、キー送信パイプライン |
| feature/key-management | worktree/key-management | SSH鍵生成、鍵インポート |
| feature/settings | worktree/settings | 設定保存、通知ルール保存 |

## 作業分担

### %107 - SSH/Terminal担当
- SSH接続確立とシェルセッション開始
- ターミナルキー入力/出力パイプライン
- Tmuxセッション一覧・選択

### %108 - 鍵管理担当
- Ed25519/RSA鍵生成
- 鍵インポート（PEMファイル）
- SecureStorage保存

### %109 - 設定担当
- 設定画面の保存機能
- 通知ルールの追加・編集・削除
