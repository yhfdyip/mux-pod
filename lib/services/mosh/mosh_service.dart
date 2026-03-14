import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../ssh/ssh_client.dart';

/// Mosh接続サービス（iOS only）
///
/// 使い方:
/// 1. bootstrapViaSsh() でSSH経由でmosh-serverを起動し、接続情報を取得
/// 2. connect() でlibmoshiosに接続
/// 3. events ストリームで出力を受信
/// 4. sendInput() でキー入力を送信
/// 5. disconnect() で切断
class MoshService {
  static const _method = MethodChannel('com.muxpod.app/mosh');
  static const _event  = EventChannel('com.muxpod.app/mosh_events');

  StreamController<MoshEvent>? _controller;
  StreamSubscription<dynamic>? _eventSub;

  /// Moshが使用可能なプラットフォームか
  static bool get isSupported => Platform.isIOS;

  /// SSH経由でmosh-serverを起動し、接続パラメータを返す
  ///
  /// サーバー側に `mosh-server` がインストールされている必要がある。
  /// 成功すると [MoshConnectParams] を返す。
  static Future<MoshConnectParams> bootstrapViaSsh({
    required SshClient sshClient,
    String moshServerPath = 'mosh-server',
  }) async {
    // mosh-server を起動して "MOSH CONNECT <port> <key>" を取得
    final output = await sshClient.exec(
      '$moshServerPath new -s 2>&1',
    );

    final match = RegExp(r'MOSH CONNECT (\d+) ([A-Za-z0-9+/=]+)')
        .firstMatch(output);
    if (match == null) {
      throw MoshBootstrapError(
        'mosh-server did not return MOSH CONNECT line.\nOutput: $output',
      );
    }

    final port = int.parse(match.group(1)!);
    final key  = match.group(2)!;
    return MoshConnectParams(port: port, key: key);
  }

  /// libmoshiosに接続する
  Future<void> connect({
    required String ip,
    required int port,
    required String key,
    int cols = 80,
    int rows = 24,
    String predict = 'adaptive',
  }) async {
    _assertSupported();
    _startEventStream();
    await _method.invokeMethod<void>('startMosh', {
      'ip':      ip,
      'port':    port.toString(),
      'key':     key,
      'cols':    cols,
      'rows':    rows,
      'predict': predict,
    });
  }

  /// 切断する
  Future<void> disconnect() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('stopMosh');
  }

  /// キー入力を送信する
  Future<void> sendInput(Uint8List data) async {
    _assertSupported();
    await _method.invokeMethod<void>('sendMoshInput', data);
  }

  /// 端末サイズを変更する
  Future<void> resize(int cols, int rows) async {
    _assertSupported();
    await _method.invokeMethod<void>('resizeMosh', {
      'cols': cols,
      'rows': rows,
    });
  }

  /// Moshイベントストリーム
  Stream<MoshEvent> get events {
    _assertSupported();
    _startEventStream();
    return _controller!.stream;
  }

  void _startEventStream() {
    if (_controller != null) return;
    _controller = StreamController<MoshEvent>.broadcast();
    _eventSub = _event.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final map = Map<String, dynamic>.from(raw);
        _controller?.add(MoshEvent.fromMap(map));
      },
      onError: (Object e) => _controller?.addError(e),
    );
  }

  /// リソースを解放する
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _controller?.close();
    _controller = null;
  }

  void _assertSupported() {
    if (!isSupported) {
      throw UnsupportedError('Mosh is only supported on iOS');
    }
  }
}

/// mosh-server 起動エラー
class MoshBootstrapError implements Exception {
  final String message;
  MoshBootstrapError(this.message);
  @override
  String toString() => 'MoshBootstrapError: $message';
}

/// mosh-server から取得した接続パラメータ
class MoshConnectParams {
  final int port;
  final String key;
  const MoshConnectParams({required this.port, required this.key});
}

/// Moshイベント種別
enum MoshEventType { output, disconnected, error }

/// iOS → Flutter のMoshイベント
class MoshEvent {
  final MoshEventType type;
  final Uint8List? data;    // type == output
  final int? exitCode;      // type == disconnected
  final String? message;    // type == error

  const MoshEvent({required this.type, this.data, this.exitCode, this.message});

  factory MoshEvent.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? '';
    switch (typeStr) {
      case 'output':
        final raw = map['data'];
        Uint8List? bytes;
        if (raw is Uint8List) {
          bytes = raw;
        } else if (raw is List) {
          bytes = Uint8List.fromList(raw.cast<int>());
        }
        return MoshEvent(type: MoshEventType.output, data: bytes);
      case 'disconnected':
        return MoshEvent(
          type: MoshEventType.disconnected,
          exitCode: map['exitCode'] as int?,
        );
      default:
        return MoshEvent(
          type: MoshEventType.error,
          message: map['message'] as String? ?? typeStr,
        );
    }
  }
}
