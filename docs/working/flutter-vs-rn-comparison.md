# MuxPod 技術選定調査: Flutter vs React Native SSH ライブラリ比較

調査日: 2026-01-11

## 背景

現在 Expo (React Native) + react-native-ssh-sftp で開発中だが、SSHライブラリがメンテナンス放棄状態（npm公開8年前）で、Androidビルドに多くのパッチが必要。

---

## 1. Flutter SSH ライブラリ

### dartssh2 (推奨)

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 2.13.0 |
| **最終更新** | 2025年2月（6ヶ月前） |
| **Pub Points** | 150 |
| **Likes** | 140 |
| **週間DL** | 5,540 |
| **GitHub Stars** | 241 |
| **Open Issues** | 63 |
| **実装方式** | Pure Dart |
| **ライセンス** | MIT |

**機能:**
- SSH セッション（コマンド実行、シェル生成、環境変数、PTY）
- 認証: パスワード、秘密鍵、インタラクティブ
- ポートフォワーディング（ローカル/リモート）
- SFTP: SFTPv3プロトコル完全対応
- SSHHttpClient（HTTPリクエストフォワーディング）
- 自動キープアライブ

**プラットフォーム対応:**
- Android, iOS, Linux, macOS, Windows, **Web**

**特徴:**
- Pure Dart実装のため、ネイティブ依存なし
- [xterm.dart](https://pub.dev/packages/xterm) と同じ TerminalStudio が開発
- アクティブにメンテナンス中（Flutter 3.24対応済み）

### ssh2 (非推奨)

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 2.2.3 |
| **最終更新** | 4年前 |
| **Pub Points** | 140 |
| **Likes** | 32 |
| **週間DL** | 105 |
| **実装方式** | Native Wrapper (NMSSH/JSch) |

**問題点:**
- 4年間更新なし
- ネイティブライブラリ依存（iOSはNMSSH、AndroidはJSch）
- デスクトップ非対応
- 未検証パブリッシャー

### xterm.dart (ターミナルエミュレータ)

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 4.0.0 |
| **最終更新** | 22ヶ月前 |
| **Likes** | 231 |
| **週間DL** | 166,000+ |

dartssh2と組み合わせてSSH端末を約100行で実装可能。

---

## 2. React Native SSH ライブラリ

### @speedshield/react-native-ssh-sftp (最も活発)

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 1.5.25 |
| **最終更新** | 4ヶ月前 |
| **対応RN** | React Native 0.73 |
| **実装方式** | Native Wrapper (NMSSH/JSch) |

**特徴:**
- react-native-ssh-sftpの最新フォーク
- 手動リンク不要（RN 0.73+）
- iOSシミュレータ非対応（実機のみ）

**問題点:**
- New Architecture (TurboModules) 未対応
- RN 0.76 / Expo SDK 52 での動作未検証
- ネイティブ依存によるビルド複雑性

### react-native-ssh-sftp (オリジナル)

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 1.0.3 |
| **最終更新** | 8年前 |
| **GitHub Stars** | 66 |
| **Open Issues** | 12 |
| **最終コミット** | 2023年2月 |

**問題点:**
- 8年間npm更新なし
- OpenSSL競合問題（Flipper vs NMSSH）
- Legacy Bridge アーキテクチャのみ
- Expo SDK 52 / RN 0.76 非対応

### @dylankenneally/react-native-ssh-sftp

| 項目 | 値 |
|------|-----|
| **最新バージョン** | 1.5.20 |
| **最終更新** | 1年前 |
| **対応RN** | React Native 0.73 |

speedshieldフォークより古い。

### WebSocket プロキシ方式

サーバー側にプロキシを設置し、WebSocket経由でSSH接続する方式。

**代表的なソリューション:**
- [WebSSH2](https://github.com/billchurch/webssh2) - Node.js + ssh2 + socket.io + xterm.js
- Go SSH Web Client - Go + gorilla/websocket

**メリット:**
- クライアント側にネイティブ依存なし
- Expo Goでも動作可能
- Web/モバイル共通実装

**デメリット:**
- サーバー側設定が必要（MuxPodの設計思想に反する）
- 追加インフラコスト
- レイテンシ増加

---

## 3. 比較表

| 観点 | dartssh2 (Flutter) | @speedshield/rn-ssh-sftp | react-native-ssh-sftp | WebSocket Proxy |
|------|---------------------|--------------------------|----------------------|-----------------|
| **メンテナンス** | ⭐⭐⭐⭐⭐ 活発 | ⭐⭐⭐ 更新あり | ⭐ 放棄 | N/A |
| **最終更新** | 6ヶ月前 | 4ヶ月前 | 8年前 | - |
| **SSH** | ✅ | ✅ | ✅ | ✅ |
| **SFTP** | ✅ SFTPv3完全対応 | ✅ | ✅ | ✅ |
| **鍵認証** | ✅ RSA/Ed25519 | ✅ | ✅ | ✅ |
| **実装方式** | Pure Dart | Native Wrapper | Native Wrapper | Server-side |
| **ネイティブ依存** | なし | あり (NMSSH/JSch) | あり (NMSSH/JSch) | なし |
| **New Architecture** | N/A | ❌ 未対応 | ❌ 未対応 | N/A |
| **Expo SDK 52対応** | N/A | ❓ 未検証 | ❌ | ✅ |
| **iOSシミュレータ** | ✅ | ❌ | ❌ | ✅ |
| **デスクトップ** | ✅ | ❌ | ❌ | ✅ |
| **Web** | ✅ | ❌ | ❌ | ✅ |
| **ビルド複雑性** | 低 | 高 | 非常に高 | 中 |
| **サーバー設定** | 不要 | 不要 | 不要 | 必要 |

---

## 4. 移行コスト分析

### Flutter移行の場合

| 作業項目 | 工数目安 |
|----------|----------|
| Dart/Flutter基礎学習 | 中 |
| プロジェクトセットアップ | 小 |
| UI移植（Expo Router → Flutter Navigator） | 大 |
| Zustand → Riverpod/Provider 移行 | 中 |
| SSH/SFTP統合（dartssh2 + xterm.dart） | 小 |
| expo-secure-store → flutter_secure_storage | 小 |
| テスト移行 | 中 |

**リスク:**
- チームのFlutter経験不足
- 既存コードベースの再実装が必要

**メリット:**
- 長期的なメンテナンス性向上
- ネイティブ依存からの解放
- パフォーマンス向上（特にアニメーション）

### React Native継続の場合

| 作業項目 | 工数目安 |
|----------|----------|
| @speedshield/react-native-ssh-sftp への移行 | 小 |
| Expo SDK 52互換性テスト | 中 |
| New Architecture対応（将来） | 大 |
| ネイティブビルド問題の継続対応 | 継続的 |

**リスク:**
- New Architecture移行時に再度問題発生
- ネイティブ依存によるビルド不安定性
- フォークのメンテナンス継続性

---

## 5. 総合評価

### 推奨: Flutter + dartssh2 + xterm.dart

**理由:**

1. **メンテナンス品質**: dartssh2は TerminalStudio が積極的にメンテナンス中。Pure Dart実装のため、OSアップデートに強い。

2. **エコシステム**: dartssh2 + xterm.dart で完全なSSHターミナルが構築可能。同一チームが開発しており、連携が良好。

3. **将来性**:
   - Flutter 2025年採用率46%（RN 35%）
   - GitHub Stars: Flutter 170k vs RN 121k
   - ネイティブ依存なしでビルドが安定

4. **開発体験**: Hot Reload、Widgetベースの一貫したUI、強力なDevTools

5. **クロスプラットフォーム**: Android, iOS, Web, Desktop全対応

### 次点: @speedshield/react-native-ssh-sftp

現状維持で最小限のリスク。ただし長期的には同じ問題が再発する可能性あり。

### 非推奨: WebSocket Proxy

MuxPodの「sshdのみで動作」という設計思想に反する。

---

## 6. 参考リンク

### Flutter
- [dartssh2 - pub.dev](https://pub.dev/packages/dartssh2)
- [dartssh2 - GitHub](https://github.com/TerminalStudio/dartssh2)
- [xterm.dart - pub.dev](https://pub.dev/packages/xterm)
- [ssh2 - pub.dev](https://pub.dev/packages/ssh2)

### React Native
- [@speedshield/react-native-ssh-sftp - npm](https://www.npmjs.com/package/@speedshield/react-native-ssh-sftp)
- [react-native-ssh-sftp - GitHub](https://github.com/shaqian/react-native-ssh-sftp)
- [@dylankenneally/react-native-ssh-sftp - npm](https://www.npmjs.com/package/@dylankenneally/react-native-ssh-sftp)

### WebSocket Proxy
- [WebSSH2 - GitHub](https://github.com/billchurch/webssh2)
- [xterm.js](https://xtermjs.org/)

### 比較記事
- [Flutter vs React Native in 2025](https://medium.com/apparence/flutter-vs-react-native-in-2025-which-one-to-choose-fdf34e50f342)
- [Flutter vs React Native: Complete 2025 Guide](https://www.thedroidsonroids.com/blog/flutter-vs-react-native-comparison)
