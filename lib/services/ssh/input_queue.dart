/// 切断中の入力をキューイングするクラス
///
/// SSH接続が切断されている間のキー入力を保持し、
/// 再接続後にまとめて送信できるようにする。
class InputQueue {
  final List<String> _queue = [];

  /// 最大キューサイズ（文字数）
  static const int maxSize = 1000;

  /// キューに入力を追加
  ///
  /// maxSizeを超える場合は追加されず、isOverflowがtrueになる。
  void enqueue(String input) {
    if (length + input.length <= maxSize) {
      _queue.add(input);
    }
  }

  /// キュー内のすべての入力を取り出して結合
  ///
  /// 取り出し後、キューは空になる。
  String flush() {
    if (_queue.isEmpty) return '';
    final result = _queue.join();
    _queue.clear();
    return result;
  }

  /// キューをクリア
  void clear() {
    _queue.clear();
  }

  /// キューが空か
  bool get isEmpty => _queue.isEmpty;

  /// キュー内の合計文字数
  int get length {
    int total = 0;
    for (final item in _queue) {
      total += item.length;
    }
    return total;
  }

  /// オーバーフロー状態か（これ以上追加できない）
  bool get isOverflow => length >= maxSize;

  /// キュー内のアイテム数
  int get itemCount => _queue.length;
}
