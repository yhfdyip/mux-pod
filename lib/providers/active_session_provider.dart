import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmux/tmux_parser.dart';

/// アクティブセッション情報
class ActiveSession {
  final String connectionId;
  final String connectionName;
  final String host;
  final String sessionName;
  final int windowCount;
  final DateTime connectedAt;
  final bool isAttached;

  const ActiveSession({
    required this.connectionId,
    required this.connectionName,
    required this.host,
    required this.sessionName,
    required this.windowCount,
    required this.connectedAt,
    this.isAttached = true,
  });

  ActiveSession copyWith({
    String? connectionId,
    String? connectionName,
    String? host,
    String? sessionName,
    int? windowCount,
    DateTime? connectedAt,
    bool? isAttached,
  }) {
    return ActiveSession(
      connectionId: connectionId ?? this.connectionId,
      connectionName: connectionName ?? this.connectionName,
      host: host ?? this.host,
      sessionName: sessionName ?? this.sessionName,
      windowCount: windowCount ?? this.windowCount,
      connectedAt: connectedAt ?? this.connectedAt,
      isAttached: isAttached ?? this.isAttached,
    );
  }
}

/// アクティブセッション一覧の状態
class ActiveSessionsState {
  final List<ActiveSession> sessions;
  final String? currentSessionKey; // connectionId:sessionName

  const ActiveSessionsState({
    this.sessions = const [],
    this.currentSessionKey,
  });

  ActiveSessionsState copyWith({
    List<ActiveSession>? sessions,
    String? currentSessionKey,
    bool clearCurrentSession = false,
  }) {
    return ActiveSessionsState(
      sessions: sessions ?? this.sessions,
      currentSessionKey:
          clearCurrentSession ? null : (currentSessionKey ?? this.currentSessionKey),
    );
  }

  /// 指定した接続のセッション一覧を取得
  List<ActiveSession> getSessionsForConnection(String connectionId) {
    return sessions.where((s) => s.connectionId == connectionId).toList();
  }

  /// 現在のセッションを取得
  ActiveSession? get currentSession {
    if (currentSessionKey == null) return null;
    try {
      return sessions.firstWhere(
        (s) => '${s.connectionId}:${s.sessionName}' == currentSessionKey,
      );
    } catch (e) {
      return null;
    }
  }
}

/// アクティブセッションを管理するNotifier
class ActiveSessionsNotifier extends Notifier<ActiveSessionsState> {
  @override
  ActiveSessionsState build() {
    return const ActiveSessionsState();
  }

  /// セッションを追加または更新
  void addOrUpdateSession({
    required String connectionId,
    required String connectionName,
    required String host,
    required String sessionName,
    required int windowCount,
    bool isAttached = true,
  }) {
    final key = '$connectionId:$sessionName';
    final existingIndex = state.sessions.indexWhere(
      (s) => '${s.connectionId}:${s.sessionName}' == key,
    );

    final session = ActiveSession(
      connectionId: connectionId,
      connectionName: connectionName,
      host: host,
      sessionName: sessionName,
      windowCount: windowCount,
      connectedAt:
          existingIndex >= 0 ? state.sessions[existingIndex].connectedAt : DateTime.now(),
      isAttached: isAttached,
    );

    final sessions = [...state.sessions];
    if (existingIndex >= 0) {
      sessions[existingIndex] = session;
    } else {
      sessions.add(session);
    }

    state = state.copyWith(sessions: sessions);
  }

  /// 接続のセッション一覧を更新（tmuxセッションリストから）
  void updateSessionsForConnection({
    required String connectionId,
    required String connectionName,
    required String host,
    required List<TmuxSession> tmuxSessions,
  }) {
    // 既存のセッションを保持しつつ更新
    final otherSessions = state.sessions
        .where((s) => s.connectionId != connectionId)
        .toList();

    final newSessions = tmuxSessions.map((ts) {
      return ActiveSession(
        connectionId: connectionId,
        connectionName: connectionName,
        host: host,
        sessionName: ts.name,
        windowCount: ts.windowCount,
        connectedAt: DateTime.now(),
        isAttached: ts.attached,
      );
    }).toList();

    state = state.copyWith(sessions: [...otherSessions, ...newSessions]);
  }

  /// 現在のセッションを設定
  void setCurrentSession(String connectionId, String sessionName) {
    state = state.copyWith(currentSessionKey: '$connectionId:$sessionName');
  }

  /// 現在のセッションをクリア
  void clearCurrentSession() {
    state = state.copyWith(clearCurrentSession: true);
  }

  /// セッションを削除
  void removeSession(String connectionId, String sessionName) {
    final sessions = state.sessions
        .where((s) => !(s.connectionId == connectionId && s.sessionName == sessionName))
        .toList();
    state = state.copyWith(sessions: sessions);
  }

  /// 接続の全セッションを削除
  void removeSessionsForConnection(String connectionId) {
    final sessions =
        state.sessions.where((s) => s.connectionId != connectionId).toList();
    state = state.copyWith(sessions: sessions);
  }

  /// 全セッションをクリア
  void clear() {
    state = const ActiveSessionsState();
  }
}

/// アクティブセッションプロバイダー
final activeSessionsProvider =
    NotifierProvider<ActiveSessionsNotifier, ActiveSessionsState>(() {
  return ActiveSessionsNotifier();
});
