import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/active_session_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/keychain/secure_storage.dart';
import '../../services/ssh/ssh_client.dart';
import '../../services/tmux/tmux_commands.dart';
import '../../services/tmux/tmux_parser.dart';
import '../../theme/design_colors.dart';
import 'connection_form_screen.dart';
import '../terminal/terminal_screen.dart';

/// 接続一覧画面
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsState = ref.watch(connectionsProvider);
    developer.log(
      'ConnectionsScreen.build() - connections: ${connectionsState.connections.length}, isLoading: ${connectionsState.isLoading}',
      name: 'ConnectionsScreen',
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            sliver: _buildBody(context, ref, connectionsState),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, ref),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 100,
      backgroundColor: DesignColors.canvasDark.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connections',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'GATEWAY_STATUS: ONLINE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: DesignColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: DesignColors.textSecondary),
          onPressed: () {},
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.sort, color: DesignColors.textSecondary),
          onPressed: () {},
          tooltip: 'Sort',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFAB(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: FloatingActionButton.extended(
        heroTag: 'fab_add_connection',
        onPressed: () => _addConnection(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add New Connection'),
        elevation: 0,
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ConnectionsState state) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null) {
      return SliverFillRemaining(
        child: _buildErrorState(context, ref, state.error!),
      );
    }

    if (state.connections.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final connection = state.connections[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ConnectionCard(
              connection: connection,
              onConnect: (sessionName) =>
                  _connectToServer(context, ref, connection, sessionName),
              onEdit: () => _editConnection(context, ref, connection),
              onDelete: () => _deleteConnection(context, ref, connection),
            ),
          );
        },
        childCount: state.connections.length,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: DesignColors.error),
          const SizedBox(height: 16),
          Text(
            'Error loading connections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(error, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(connectionsProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DesignColors.borderDark),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 64,
              color: DesignColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No connections yet',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first server',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: DesignColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _addConnection(BuildContext context, WidgetRef ref) async {
    developer.log('_addConnection() - navigating to ConnectionFormScreen', name: 'ConnectionsScreen');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const ConnectionFormScreen()),
    );
    developer.log('_addConnection() - returned with result: $result', name: 'ConnectionsScreen');
    if (result == true) {
      developer.log('_addConnection() - invalidating connectionsProvider', name: 'ConnectionsScreen');
      ref.invalidate(connectionsProvider);
    }
  }

  void _editConnection(BuildContext context, WidgetRef ref, Connection connection) async {
    developer.log('_editConnection() - navigating to ConnectionFormScreen for ${connection.id}', name: 'ConnectionsScreen');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ConnectionFormScreen(connectionId: connection.id),
      ),
    );
    developer.log('_editConnection() - returned with result: $result', name: 'ConnectionsScreen');
    if (result == true) {
      developer.log('_editConnection() - invalidating connectionsProvider', name: 'ConnectionsScreen');
      ref.invalidate(connectionsProvider);
    }
  }

  Future<void> _deleteConnection(
    BuildContext context,
    WidgetRef ref,
    Connection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Are you sure you want to delete "${connection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: DesignColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = SecureStorageService();
      await storage.deletePassword(connection.id);
      await ref.read(connectionsProvider.notifier).remove(connection.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${connection.name} deleted')),
        );
      }
    }
  }

  void _connectToServer(
    BuildContext context,
    WidgetRef ref,
    Connection connection,
    String? sessionName,
  ) {
    ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TerminalScreen(
          connectionId: connection.id,
          sessionName: sessionName,
        ),
      ),
    );
  }
}

/// 接続カード（展開可能、tmuxセッション表示）
class _ConnectionCard extends ConsumerStatefulWidget {
  final Connection connection;
  final void Function(String? sessionName) onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectionCard({
    required this.connection,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _isExpanded = false;
  bool _isLoadingSessions = false;
  List<TmuxSession> _sessions = [];
  String? _sessionError;

  @override
  Widget build(BuildContext context) {
    // アクティブセッションからこの接続のセッション情報を取得
    final activeSessionsState = ref.watch(activeSessionsProvider);
    final activeSessions =
        activeSessionsState.getSessionsForConnection(widget.connection.id);
    final hasActiveSessions = activeSessions.isNotEmpty;

    // 接続状態の判定（アクティブセッションがあるか、lastConnectedAtがあるか）
    final isConnected = hasActiveSessions || widget.connection.lastConnectedAt != null;
    final statusColor = hasActiveSessions
        ? DesignColors.success
        : (isConnected ? Colors.orange : DesignColors.textMuted);

    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          InkWell(
            onTap: () => _toggleExpand(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status Icon
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasActiveSessions
                              ? const Color(0xFF153E42)
                              : DesignColors.borderDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasActiveSessions
                                ? const Color(0xFF1F5F66)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          Icons.dns,
                          size: 20,
                          color: hasActiveSessions
                              ? DesignColors.primary
                              : DesignColors.textSecondary,
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DesignColors.surfaceDark,
                              width: 2,
                            ),
                            boxShadow: hasActiveSessions
                                ? [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Connection Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.connection.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.connection.host} • ${widget.connection.username}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: DesignColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand Icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: DesignColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content - Sessions List
          if (_isExpanded) _buildExpandedContent(activeSessions),
        ],
      ),
    );
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    // 展開時にセッション情報をフェッチ
    if (_isExpanded && _sessions.isEmpty && !_isLoadingSessions) {
      _fetchSessions();
    }
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionError = null;
    });

    try {
      final connection = widget.connection;
      final storage = SecureStorageService();

      // 認証オプションを取得
      SshConnectOptions options;
      if (connection.authMethod == 'key' && connection.keyId != null) {
        final privateKey = await storage.getPrivateKey(connection.keyId!);
        final passphrase = await storage.getPassphrase(connection.keyId!);
        options = SshConnectOptions(privateKey: privateKey, passphrase: passphrase);
      } else {
        final password = await storage.getPassword(connection.id);
        options = SshConnectOptions(password: password);
      }

      // SSH接続してセッション一覧を取得
      final sshClient = SshClient();
      await sshClient.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      final output = await sshClient.exec(TmuxCommands.listSessions());
      final sessions = TmuxParser.parseSessions(output);

      // 切断
      await sshClient.disconnect();

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });

      // ActiveSessionsProviderを更新
      ref.read(activeSessionsProvider.notifier).updateSessionsForConnection(
            connectionId: connection.id,
            connectionName: connection.name,
            host: connection.host,
            tmuxSessions: sessions,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSessions = false;
        _sessionError = e.toString();
      });
    }
  }

  Widget _buildExpandedContent(List<ActiveSession> activeSessions) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF15161C),
        border: Border(top: BorderSide(color: DesignColors.borderDark)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sessions Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'ACTIVE SESSIONS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: DesignColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Sessions List
          if (_isLoadingSessions)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_sessionError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _sessionError!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: DesignColors.error,
                ),
              ),
            )
          else if (_sessions.isEmpty && activeSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No tmux sessions found',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: DesignColors.textMuted,
                ),
              ),
            )
          else
            // セッションリスト（_sessionsまたはactiveSessionsを使用）
            ..._buildSessionItems(),
          // New Session Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => widget.onConnect(null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignColors.primary.withValues(alpha: 0.8),
                side: BorderSide(
                  color: DesignColors.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
          const Divider(color: DesignColors.borderDark, height: 1),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: DesignColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: DesignColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionItems() {
    // _sessionsを使用（フェッチ結果）
    final sessions = _sessions;
    if (sessions.isEmpty) return [];

    return sessions.map((session) {
      final isAttached = session.attached;
      return InkWell(
        onTap: () => widget.onConnect(session.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.terminal,
                size: 16,
                color: isAttached ? DesignColors.primary : DesignColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${session.windowCount} windows',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: DesignColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAttached
                      ? const Color(0xFF14532D).withValues(alpha: 0.5)
                      : DesignColors.borderDark,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isAttached
                        ? const Color(0xFF166534).withValues(alpha: 0.7)
                        : DesignColors.borderDark,
                  ),
                ),
                child: Text(
                  isAttached ? 'Attached' : 'Detached',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isAttached ? const Color(0xFF4ADE80) : DesignColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
