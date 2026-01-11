import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

import '../../providers/connection_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tmux_provider.dart';
import '../../services/keychain/secure_storage.dart';
import '../../services/ssh/ssh_client.dart';
import '../../services/tmux/tmux_commands.dart';
import '../../services/tmux/tmux_parser.dart';
import '../../theme/design_colors.dart';
import '../../widgets/special_keys_bar.dart';

/// ターミナル画面（HTMLデザイン仕様準拠）
class TerminalScreen extends ConsumerStatefulWidget {
  final String connectionId;
  final String? sessionName;

  const TerminalScreen({
    super.key,
    required this.connectionId,
    this.sessionName,
  });

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late Terminal _terminal;
  final _terminalController = TerminalController();
  final _secureStorage = SecureStorageService();

  // 接続状態
  bool _isConnecting = false;
  String? _connectionError;

  // UI表示用（後でtmux状態から取得）
  String _currentSession = '';
  String _currentWindow = '';
  int _latency = 0;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    // ターミナルリサイズ時のハンドラ設定
    _terminal.onResize = _onTerminalResize;
    _connectAndAttach();
  }

  /// ターミナルリサイズハンドラ
  void _onTerminalResize(int cols, int rows, int pixelWidth, int pixelHeight) {
    final sshState = ref.read(sshProvider);
    if (sshState.isConnected) {
      ref.read(sshProvider.notifier).resize(cols, rows);
    }
  }

  Future<void> _connectAndAttach() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // 1. 接続情報を取得
      final connection = ref.read(connectionsProvider.notifier).getById(widget.connectionId);
      if (connection == null) {
        throw Exception('Connection not found');
      }

      // 2. 認証情報を取得
      final options = await _getAuthOptions(connection);

      // 3. SSH接続
      final sshNotifier = ref.read(sshProvider.notifier);
      await sshNotifier.connect(connection, options);

      // 4. イベントハンドラを設定
      final sshClient = sshNotifier.client;
      if (sshClient != null) {
        sshClient.setEventHandlers(SshEvents(
          onData: (Uint8List data) {
            _terminal.write(String.fromCharCodes(data));
          },
          onClose: _handleDisconnect,
          onError: _handleError,
        ));
      }

      // 5. tmuxセッション一覧を取得
      final sessionsOutput = await sshClient?.exec(TmuxCommands.listSessions());
      if (sessionsOutput != null) {
        final sessions = TmuxParser.parseSessions(sessionsOutput);
        ref.read(tmuxProvider.notifier).updateSessions(sessions);

        // 6. セッションにアタッチまたは新規作成
        if (sessions.isNotEmpty) {
          final sessionName = widget.sessionName ?? sessions.first.name;
          sshClient?.write('${TmuxCommands.attachSession(sessionName)}\n');
          ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
          setState(() {
            _currentSession = sessionName;
          });
        } else {
          final newSessionName = 'muxpod-${DateTime.now().millisecondsSinceEpoch}';
          sshClient?.write('${TmuxCommands.newSession(name: newSessionName, detached: false)}\n');
          ref.read(tmuxProvider.notifier).setActiveSession(newSessionName);
          setState(() {
            _currentSession = newSessionName;
          });
        }
      }

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });
      _showErrorSnackBar(e.toString());
    }
  }

  /// 認証オプションを取得
  Future<SshConnectOptions> _getAuthOptions(Connection connection) async {
    if (connection.authMethod == 'key' && connection.keyId != null) {
      final privateKey = await _secureStorage.getPrivateKey(connection.keyId!);
      final passphrase = await _secureStorage.getPassphrase(connection.keyId!);
      return SshConnectOptions(privateKey: privateKey, passphrase: passphrase);
    } else {
      final password = await _secureStorage.getPassword(connection.id);
      return SshConnectOptions(password: password);
    }
  }

  /// 切断ハンドラ
  void _handleDisconnect() {
    if (mounted) {
      _showErrorSnackBar('Connection closed');
      Navigator.of(context).pop();
    }
  }

  /// エラーハンドラ
  void _handleError(Object error) {
    if (mounted) {
      _showErrorSnackBar('Error: $error');
    }
  }

  /// エラーSnackBar表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _connectAndAttach,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _terminalController.dispose();
    // SSH接続をクリーンアップ
    ref.read(sshProvider.notifier).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sshState = ref.watch(sshProvider);

    return Scaffold(
      backgroundColor: DesignColors.backgroundDark,
      body: Stack(
        children: [
          Column(
            children: [
              _buildBreadcrumbHeader(),
              Expanded(
                child: Stack(
                  children: [
                    TerminalView(
                      _terminal,
                      controller: _terminalController,
                      autofocus: true,
                      backgroundOpacity: 1.0,
                      theme: _buildTerminalTheme(),
                      textStyle: TerminalStyle.fromTextStyle(
                        GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    // Pane indicator (右上)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildPaneIndicator(),
                    ),
                  ],
                ),
              ),
              SpecialKeysBar(
                onKeyPressed: _sendKey,
                onInputTap: _showInputDialog,
              ),
            ],
          ),
          // ローディングオーバーレイ
          if (_isConnecting || sshState.isConnecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // エラーオーバーレイ
          if (_connectionError != null || sshState.hasError)
            _buildErrorOverlay(sshState.error ?? _connectionError),
        ],
      ),
    );
  }

  /// エラーオーバーレイ
  Widget _buildErrorOverlay(String? error) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error ?? 'Connection error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _connectAndAttach,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// 上部のパンくずナビゲーションヘッダー
  Widget _buildBreadcrumbHeader() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: DesignColors.surfaceDark.withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF2A2B36), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Server icon
            Icon(
              Icons.dns,
              size: 14,
              color: DesignColors.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            // Breadcrumb navigation
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBreadcrumbItem(_currentSession, isActive: true),
                    _buildBreadcrumbSeparator(),
                    _buildBreadcrumbItem(_currentWindow, isSelected: true),
                    _buildBreadcrumbSeparator(),
                    _buildBreadcrumbItem('htop', isActive: false),
                    _buildBreadcrumbSeparator(),
                    _buildBreadcrumbItem('nvim', isActive: false),
                  ],
                ),
              ),
            ),
            // Latency indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFF2A2B36), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 10,
                    color: DesignColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_latency}ms',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: DesignColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Settings button
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.settings,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbItem(String label, {bool isActive = false, bool isSelected = false}) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : EdgeInsets.zero,
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              )
            : null,
        child: Row(
          children: [
            if (isSelected)
              Icon(
                Icons.article,
                size: 12,
                color: DesignColors.primary,
              ),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: isActive || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? DesignColors.primary
                    : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '/',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w300,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  /// 右上のペインインジケーター
  Widget _buildPaneIndicator() {
    return Opacity(
      opacity: 0.3,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: DesignColors.primary),
              color: DesignColors.primary.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  TerminalTheme _buildTerminalTheme() {
    return TerminalTheme(
      cursor: DesignColors.primary,
      selection: DesignColors.primary.withValues(alpha: 0.3),
      foreground: Colors.white.withValues(alpha: 0.9),
      background: DesignColors.backgroundDark,
      black: const Color(0xFF000000),
      red: DesignColors.terminalRed,
      green: DesignColors.terminalGreen,
      yellow: DesignColors.terminalYellow,
      blue: DesignColors.terminalBlue,
      magenta: DesignColors.terminalMagenta,
      cyan: DesignColors.terminalCyan,
      white: const Color(0xFFE0E0E0),
      brightBlack: const Color(0xFF808080),
      brightRed: const Color(0xFFFF6B6B),
      brightGreen: const Color(0xFF69FF94),
      brightYellow: const Color(0xFFFFF36D),
      brightBlue: const Color(0xFF76A9FA),
      brightMagenta: const Color(0xFFD4A5FF),
      brightCyan: const Color(0xFF7FDBFF),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: DesignColors.primary.withValues(alpha: 0.3),
      searchHitBackgroundCurrent: DesignColors.primary.withValues(alpha: 0.5),
      searchHitForeground: Colors.white,
    );
  }

  void _sendKey(String key) {
    final sshState = ref.read(sshProvider);
    if (sshState.isConnected) {
      ref.read(sshProvider.notifier).write(key);
    }
    // ローカルエコーは不要（サーバーから返ってくる）
  }

  void _showInputDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: DesignColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter Command',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your command...',
                hintStyle: GoogleFonts.jetBrainsMono(
                  color: DesignColors.textMuted,
                ),
                filled: true,
                fillColor: DesignColors.inputDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: DesignColors.primary),
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _sendKey('$value\r');
                }
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final value = controller.text;
                if (value.isNotEmpty) {
                  _sendKey('$value\r');
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Execute',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
