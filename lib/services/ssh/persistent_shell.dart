import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// 持続的シェルセッション
///
/// コマンドを書き込み、マーカーで出力終了を検知して結果を返す。
/// チャネル開閉のオーバーヘッドを排除し、1 RTT程度でコマンド実行可能。
class PersistentShell {
  final SSHClient _sshClient;
  SSHSession? _session;

  /// マーカーのコアテキスト
  static const String _markerId = '7f3d8a2b';

  /// コマンド開始検知用マーカー（\x01プレフィックス/サフィックス付き）
  ///
  /// \x01（SOH制御文字）を含めることで、シェルのエコーバックテキスト内の
  /// リテラル文字列（`\x01`=4文字）と区別する。
  /// printfの実出力のみがバイト0x01を含むため、エコーバック内では一致しない。
  static const String _startMarker = '\x01###START_$_markerId###\x01';

  /// コマンド終了検知用マーカー
  static const String _endMarker = '\x01###END_$_markerId###\x01';

  /// printf用のマーカー文字列（シェルコマンド内で使用）
  static const String _printfStartMarker =
      r'\x01###START_'
      '$_markerId'
      r'###\x01';
  static const String _printfEndMarker =
      r'\x01###END_'
      '$_markerId'
      r'###\x01';

  static final List<int> _startMarkerBytes = utf8.encode(_startMarker);
  static final List<int> _endMarkerBytes = utf8.encode(_endMarker);

  /// 出力バッファ（バイト列として蓄積し、UTF-8マルチバイト境界分割を防ぐ）
  final _rawBuffer = <int>[];

  int _startMarkerIndex = -1;
  int _searchFrom = 0;

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

    // ヒストリー記録を無効化（Bash/Zsh/fish対応）し、プロンプトを抑制
    // - export HISTFILE=... : Bash/Zsh用（スタートアップファイル後に上書き）
    // - set fish_history ... : fish用（exportはfishで構文エラーになるため別途）
    // - 2>/dev/null で未対応シェルのエラーを抑制
    _session!.write(
      utf8.encode(
        'export HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 SAVEHIST=0 2>/dev/null;'
        ' set fish_history "" 2>/dev/null; true;'
        ' export PS1="" PS2="" 2>/dev/null; stty -echo\n',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 100));

    // バッファをクリア（初期化出力を破棄）
    _resetParseState();
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
    _resetParseState();

    // printfでマーカーを出力（\x01バイトを含む）
    // echoではなくprintfを使用: シェルのエコーバック内ではリテラル'\x01'（4文字）が
    // 表示されるが、printfの実出力はバイト0x01を含む。
    // これによりエコーバック内のマーカーと実出力のマーカーを確実に区別できる。
    final commandWithMarkers =
        "printf '$_printfStartMarker\\n'; $command; printf '$_printfEndMarker\\n'\n";
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

    // デバッグ: UTF-8境界分割の検出（debugビルドのみ）
    assert(() {
      _debugCheckUtf8BoundarySplit(data);
      return true;
    }());

    // バイト列として蓄積（チャンク単位デコードによるUTF-8境界分割を防止）
    _rawBuffer.addAll(data);
    final startAfter = _ensureStartMarker();
    if (startAfter == null) {
      _searchFrom = _calculateNextSearchFrom(
        bufferLength: _rawBuffer.length,
        needleLength: _startMarkerBytes.length,
        minFrom: 0,
      );
      return;
    }
    final endIndex = _indexOfBytes(_rawBuffer, _endMarkerBytes, _searchFrom);
    if (endIndex == -1) {
      _searchFrom = _calculateNextSearchFrom(
        bufferLength: _rawBuffer.length,
        needleLength: _endMarkerBytes.length,
        minFrom: startAfter,
      );
      return;
    }
    final resultBytes = _rawBuffer.sublist(startAfter, endIndex);
    final result = _normalizeCommandOutput(
      utf8.decode(resultBytes, allowMalformed: true),
    );

    // Completerを先にnullにしてから完了（再入防止）
    _pendingCommand = null;
    _resetParseState();
    pending.complete(result);
  }

  void _debugCheckUtf8BoundarySplit(Uint8List data) {
    final chunkDecoded = utf8.decode(data, allowMalformed: true);
    if (!chunkDecoded.contains('\uFFFD')) return;
    final lastBytes = data.length > 6 ? data.sublist(data.length - 6) : data;
    debugPrint(
      '[PersistentShell] UTF-8 boundary split detected!'
      ' chunk_size=${data.length}'
      ' last_bytes=${lastBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
    );
  }

  void _resetParseState() {
    _rawBuffer.clear();
    _startMarkerIndex = -1;
    _searchFrom = 0;
  }

  int? _ensureStartMarker() {
    if (_startMarkerIndex != -1) {
      return _startMarkerIndex + _startMarkerBytes.length;
    }
    final startIndex = _indexOfBytes(
      _rawBuffer,
      _startMarkerBytes,
      _searchFrom,
    );
    if (startIndex == -1) {
      return null;
    }
    _startMarkerIndex = startIndex;
    _searchFrom = _startMarkerIndex + _startMarkerBytes.length;
    return _searchFrom;
  }

  int _calculateNextSearchFrom({
    required int bufferLength,
    required int needleLength,
    required int minFrom,
  }) {
    final candidate = bufferLength - needleLength + 1;
    final next = candidate < 0 ? 0 : candidate;
    return next < minFrom ? minFrom : next;
  }

  int _indexOfBytes(List<int> haystack, List<int> needle, int start) {
    if (needle.isEmpty) return start <= haystack.length ? start : -1;
    if (start < 0) return -1;
    final maxStart = haystack.length - needle.length;
    for (var i = start; i <= maxStart; i++) {
      var matched = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  String _normalizeCommandOutput(String raw) {
    // PTYの出力変換で\r\nや\rが使われる場合があるため正規化
    // 事実: macOS PTYではnewlines=0, CRs=19（\nが\rに変換されている）
    var result = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 先頭と末尾の改行を削除（マーカーのprintfで付与した改行）
    if (result.startsWith('\n')) {
      result = result.substring(1);
    }
    if (result.endsWith('\n')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// セッション終了時の処理
  void _onDone() {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(
        PersistentShellError('Shell session closed'),
      );
    }
  }

  /// エラー発生時の処理
  void _onError(Object error) {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(
        PersistentShellError('Shell error: $error'),
      );
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

    _resetParseState();
  }
}

/// PersistentShellのエラー
class PersistentShellError implements Exception {
  final String message;

  PersistentShellError(this.message);

  @override
  String toString() => 'PersistentShellError: $message';
}
