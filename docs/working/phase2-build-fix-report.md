# Phase 2 Android Build Fix レポート

## 概要
- **開始日時**: 2026-01-11
- **担当エージェント**: %105 (tmux window: fix-build)
- **目的**: expo-module-gradle-plugin エラーの解決

---

## 作業ログ

### 1. 初期調査
- GitHub Issue #36638, #38350 を参照
- expo-modules-core の Gradle プラグイン構造を確認

### 2. 依存関係修正 (完了)
`expo install --check` で以下のバージョン不整合を検出し、`--fix` で修正:

| パッケージ | 修正前 | 修正後 |
|-----------|--------|--------|
| @expo/vector-icons | 15.0.3 | ~14.0.4 |
| expo-clipboard | 8.0.8 | ~7.0.1 |
| expo-document-picker | 14.0.8 | ~13.0.3 |
| expo-file-system | 19.0.21 | ~18.0.12 |
| expo-font | 14.0.10 | ~13.0.4 |
| expo-local-authentication | 17.0.8 | ~15.0.2 |
| expo-splash-screen | 31.0.13 | ~0.29.24 |
| react-native | 0.76.0 | 0.76.9 |

### 3. package.json overrides 追加 (完了)
```json
"pnpm": {
  "overrides": {
    "expo-constants": "~17.0.8",
    "expo-linking": "~7.0.5"
  }
}
```

### 4. prebuild 再実行 (完了)
- `rm -rf android && pnpm exec expo prebuild --platform android`
- android/local.properties を再作成

### 5. react-native-ssh-sftp パッチ (完了)
**エラー**: `compile()` が古い Gradle 構文
- `pnpm patch react-native-ssh-sftp@1.0.3` でパッチ準備
- `compile` → `implementation` に変更
- compileSdkVersion, targetSdkVersion を動的に取得するよう修正 (safeExtGet関数追加)
- namespace "com.xhx.ssh" 追加
- buildscript ブロック削除
- `pnpm patch-commit` 完了

### 6. prebuild 再実行 (完了)
- パッチ適用後、android ディレクトリを再生成
- local.properties を再作成

### 7. Android ビルド (進行中)
- `pnpm android` 実行中 (timeout: 10分)
- 開始: 15m21s経過時点
- **エラー**: ネットワークタイムアウト (oss.sonatype.org への接続)
- Gradleキャッシュをクリアして再試行 → 同じエラー
- curl で接続テスト → oss.sonatype.org タイムアウト確認、dl.google.com は OK
- gradle.properties を読み込み中、リポジトリスキップ設定を検討
- Gradleオフラインモードでビルド試行 → 依存解決失敗
- ~/.gradle/init.d/skip-sonatype.gradle 作成完了（sonatypeリポジトリをスキップ）
- expo prebuild 再実行（ディレクトリエラー後に回復）
- gradlew assembleDebug → sonatype問題解決！
- **追加パッチ**: react-native-ssh-sftp AndroidManifest.xml (package属性削除)
- gradlew assembleDebug → 警告あり（MapBuilder deprecated）、コンパイルエラーあり
- **追加パッチ**: RNSshClientModule.java (android.support.annotation → androidx.annotation)
- node_modules問題発生 → パッチ適用後にモジュールが見つからない

### 8. ライブラリ調査 (完了)

#### react-native-ssh-sftp (shaqian/react-native-ssh-sftp)
| 項目 | 状態 |
|------|------|
| 最終コミット | 2023年1月25日 (約2年前) |
| npm最終公開 | 8年前 (v1.0.3) |
| スター | 66 |
| オープンIssue | 12件 |
| オープンPR | 19件 (放置) |
| 週間DL数 | 約26件 |

**結論**: 完全にメンテナンス放棄状態

#### 代替ライブラリ
| パッケージ | 最終更新 | 状態 |
|------------|----------|------|
| @speedshield/react-native-ssh-sftp | 4ヶ月前 (v1.5.25) | RN 0.73対応、0.76未検証 |
| @dylankenneally/react-native-ssh-sftp | フォーク | libssh更新版 |

#### 推奨案
1. **@speedshield/react-native-ssh-sftp** (★★★☆☆) - 移行検討
2. **WebSocketプロキシ方式** (★★★★☆) - サーバー経由
3. **Expo Modulesで自作** (★★☆☆☆) - 開発工数大

### 9. Flutter vs React Native 比較調査 (進行中)
- **担当エージェント**: %106 (tmux window: flutter-research)
- **調査項目**: Flutter SSHライブラリ、RN代替案、比較表作成
- **出力先**: docs/working/flutter-vs-rn-comparison.md

---

## 承認履歴

| 時刻 | 承認内容 |
|------|----------|
| - | pnpm list コマンド (今後確認不要に設定) |
| - | expo install コマンド (今後確認不要に設定) |
| - | パッチファイル作成 |
| - | pnpm patch コマンド (今後確認不要に設定) |

---

## 次のステップ
1. react-native-ssh-sftp パッチ適用完了
2. `pnpm android` 再実行
3. ビルド成功確認
4. 変更をコミット

---

## ステータス
**進行中** - react-native-ssh-sftp パッチ適用中
