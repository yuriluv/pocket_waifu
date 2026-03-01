import 'dart:async';

class Live2DCommandQueue {
  Live2DCommandQueue._();

  static final Live2DCommandQueue instance = Live2DCommandQueue._();

  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(Future<void> Function() task) {
    final completer = Completer<void>();
    _tail = _tail.then((_) => task()).then<void>((_) {
      completer.complete();
    }).catchError((Object _, StackTrace stackTrace) {
      completer.complete();
    });
    return completer.future;
  }

  void reset() {
    _tail = Future<void>.value();
  }
}
