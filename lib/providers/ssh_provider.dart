import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/foreground_task_service.dart';
import '../services/ssh/ssh_client.dart';
import 'connection_provider.dart';

/// SSH接続状態
class SshState {
  final SshConnectionState connectionState;
  final String? error;
  final String? sessionTitle;
  final bool isReconnecting;
  final int reconnectAttempt;
  final int? reconnectDelayMs;

  const SshState({
    this.connectionState = SshConnectionState.disconnected,
    this.error,
    this.sessionTitle,
    this.isReconnecting = false,
    this.reconnectAttempt = 0,
    this.reconnectDelayMs,
  });

  SshState copyWith({
    SshConnectionState? connectionState,
    String? error,
    String? sessionTitle,
    bool? isReconnecting,
    int? reconnectAttempt,
    int? reconnectDelayMs,
  }) {
    return SshState(
      connectionState: connectionState ?? this.connectionState,
      error: error,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      reconnectDelayMs: reconnectDelayMs,
    );
  }

  bool get isConnected => connectionState == SshConnectionState.connected;
  bool get isConnecting => connectionState == SshConnectionState.connecting;
  bool get isDisconnected => connectionState == SshConnectionState.disconnected;
  bool get hasError => connectionState == SshConnectionState.error;
}

/// SSH接続を管理するNotifier
class SshNotifier extends Notifier<SshState> {
  SshClient? _client;
  final SshForegroundTaskService _foregroundService = SshForegroundTaskService();

  // 再接続用のキャッシュ
  Connection? _lastConnection;
  SshConnectOptions? _lastOptions;
  static const int _maxReconnectAttempts = 5;
  static const List<int> _reconnectDelays = [1000, 2000, 4000, 8000, 16000]; // 指数バックオフ

  @override
  SshState build() {
    // クリーンアップを登録
    ref.onDispose(() {
      _client?.dispose();
      _foregroundService.stopService();
    });
    return const SshState();
  }

  /// SSHクライアントを取得
  SshClient? get client => _client;

  /// 最後の接続情報
  Connection? get lastConnection => _lastConnection;

  /// 最後の接続オプション
  SshConnectOptions? get lastOptions => _lastOptions;

  /// SSH接続を確立（シェル付き - 従来方式）
  Future<void> connect(Connection connection, SshConnectOptions options) async {
    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
    );

    try {
      _client = SshClient();

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      await _client!.startShell();

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
      );

      // 最終接続日時を更新
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Foreground Serviceを開始してバックグラウンドでも接続を維持
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
      );
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// SSH接続を確立（シェルなし - tmuxコマンド方式用）
  ///
  /// exec()のみ使用するため、シェルは起動しない。
  Future<void> connectWithoutShell(Connection connection, SshConnectOptions options) async {
    // 再接続用にキャッシュ
    _lastConnection = connection;
    _lastOptions = options;

    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
      isReconnecting: false,
      reconnectAttempt: 0,
    );

    try {
      _client = SshClient();

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      // シェルは起動しない（exec専用）

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        reconnectAttempt: 0,
      );

      // 最終接続日時を更新
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Foreground Serviceを開始してバックグラウンドでも接続を維持
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
      );
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// 再接続を試みる
  ///
  /// 自動再接続用。指数バックオフで最大5回まで試行する。
  Future<bool> reconnect() async {
    if (_lastConnection == null || _lastOptions == null) {
      return false;
    }

    final attempt = state.reconnectAttempt;
    if (attempt >= _maxReconnectAttempts) {
      state = state.copyWith(
        isReconnecting: false,
        error: 'Max reconnect attempts reached',
      );
      return false;
    }

    final delayMs = _reconnectDelays[attempt.clamp(0, _reconnectDelays.length - 1)];
    state = state.copyWith(
      isReconnecting: true,
      reconnectAttempt: attempt + 1,
      reconnectDelayMs: delayMs,
    );

    // 遅延後に再接続
    await Future.delayed(Duration(milliseconds: delayMs));

    try {
      // 古いクライアントをクリーンアップ
      _client?.dispose();
      _client = SshClient();

      await _client!.connect(
        host: _lastConnection!.host,
        port: _lastConnection!.port,
        username: _lastConnection!.username,
        options: _lastOptions!,
      );

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        reconnectAttempt: 0,
        error: null,
      );

      return true;
    } catch (e) {
      // 再接続失敗、次の試行を待つ
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: 'Reconnect failed: $e',
      );
      return false;
    }
  }

  /// 接続がアクティブかチェック
  bool checkConnection() {
    return _client != null && _client!.isConnected;
  }

  /// 再接続状態をリセット
  void resetReconnect() {
    state = state.copyWith(
      isReconnecting: false,
      reconnectAttempt: 0,
      reconnectDelayMs: null,
    );
  }

  /// 切断
  Future<void> disconnect() async {
    // Foreground Serviceを停止
    await _foregroundService.stopService();

    await _client?.disconnect();
    _client = null;
    state = state.copyWith(
      connectionState: SshConnectionState.disconnected,
      error: null,
      sessionTitle: null,
    );
  }

  /// セッションタイトルを更新
  void updateSessionTitle(String title) {
    state = state.copyWith(sessionTitle: title);
  }

  /// データを送信
  void write(String data) {
    _client?.write(data);
  }

  /// ターミナルサイズを変更
  void resize(int cols, int rows) {
    _client?.resize(cols, rows);
  }
}

/// SSHプロバイダー
final sshProvider = NotifierProvider<SshNotifier, SshState>(() {
  return SshNotifier();
});
