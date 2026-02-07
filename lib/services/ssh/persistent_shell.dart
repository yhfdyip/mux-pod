import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// 持続的シェルセッション
///
/// コマンドを書き込み、マーカーで出力終了を検知して結果を返す。
/// チャネル開閉のオーバーヘッドを排除し、1 RTT程度でコマンド実行可能。
class PersistentShell {
  final SSHClient _sshClient;
  SSHSession? _session;

  /// コマンド開始検知用マーカー
  static const String _startMarker = '###START_7f3d8a2b###';

  /// コマンド終了検知用マーカー
  static const String _endMarker = '###END_7f3d8a2b###';

  /// 出力バッファ
  final _outputBuffer = StringBuffer();

  /// コマンド実行中のCompleter
  Completer<String>? _pendingCommand;

  /// シェルが開始されているかどうか
  bool get isStarted => _session != null;

  /// セッション切断検知用
  bool _isClosed = false;

  /// stdoutサブスクリプション
  StreamSubscription<Uint8List>? _stdoutSubscription;

  PersistentShell(this._sshClient);

  /// シェルセッションを開始
  Future<void> start() async {
    if (_session != null) {
      return; // すでに開始済み
    }

    _session = await _sshClient.shell(
      pty: SSHPtyConfig(
        type: 'dumb', // 最小限のPTY（エスケープシーケンスを抑制）
        width: 200,
        height: 50,
      ),
    );

    _isClosed = false;

    // stdout監視を開始
    _stdoutSubscription = _session!.stdout.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
    );

    // シェル初期化を待つ（プロンプトが出力されるまで少し待機）
    await Future.delayed(const Duration(milliseconds: 100));

    // プロンプトを抑制し、エコーを無効化
    _session!.write(utf8.encode('export PS1="" PS2=""; stty -echo\n'));
    await Future.delayed(const Duration(milliseconds: 100));

    // バッファをクリア（初期化出力を破棄）
    _outputBuffer.clear();
  }

  /// コマンドを実行して結果を取得
  ///
  /// [command] 実行するコマンド
  /// [timeout] タイムアウト（デフォルト: 5秒）
  /// 戻り値: コマンドの標準出力
  Future<String> exec(String command, {Duration? timeout}) async {
    if (_session == null) {
      throw PersistentShellError('Shell not started');
    }

    if (_isClosed) {
      throw PersistentShellError('Shell session is closed');
    }

    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      throw PersistentShellError('Another command is already running');
    }

    _pendingCommand = Completer<String>();
    _outputBuffer.clear();

    // 開始マーカー + コマンド + 終了マーカーを送信
    // これにより、エコーバックやプロンプトに関係なく正確に出力を抽出できる
    final commandWithMarkers = 'echo "$_startMarker"; $command; echo "$_endMarker"\n';
    _session!.write(utf8.encode(commandWithMarkers));

    // タイムアウト付きで結果を待機
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);
    try {
      return await _pendingCommand!.future.timeout(effectiveTimeout);
    } on TimeoutException {
      _pendingCommand = null;
      throw PersistentShellError('Command execution timed out');
    }
  }

  /// stdout受信時の処理
  void _onData(Uint8List data) {
    // 待機中のコマンドがない、または完了済みの場合は無視
    final pending = _pendingCommand;
    if (pending == null || pending.isCompleted) {
      return;
    }

    final text = utf8.decode(data, allowMalformed: true);
    _outputBuffer.write(text);

    final content = _outputBuffer.toString();

    // 開始マーカーと終了マーカーの両方が揃っているかチェック
    final startIndex = content.indexOf(_startMarker);
    final endIndex = content.indexOf(_endMarker);

    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      // 開始マーカーの次の行から終了マーカーの前までを抽出
      final startPos = startIndex + _startMarker.length;
      var result = content.substring(startPos, endIndex);

      // 先頭と末尾の改行を削除
      if (result.startsWith('\n')) {
        result = result.substring(1);
      }
      if (result.endsWith('\n')) {
        result = result.substring(0, result.length - 1);
      }

      // Completerを先にnullにしてから完了（再入防止）
      _pendingCommand = null;
      _outputBuffer.clear();
      pending.complete(result);
    }
  }

  /// セッション終了時の処理
  void _onDone() {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell session closed'));
    }
  }

  /// エラー発生時の処理
  void _onError(Object error) {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell error: $error'));
    }
  }

  /// シェルセッションを再起動
  ///
  /// セッションが切断された場合に呼び出す
  Future<void> restart() async {
    await dispose();
    await start();
  }

  /// リソースを解放
  Future<void> dispose() async {
    _isClosed = true;

    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell disposed'));
    }
    _pendingCommand = null;

    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;

    _session?.close();
    _session = null;

    _outputBuffer.clear();
  }
}

/// PersistentShellのエラー
class PersistentShellError implements Exception {
  final String message;

  PersistentShellError(this.message);

  @override
  String toString() => 'PersistentShellError: $message';
}
