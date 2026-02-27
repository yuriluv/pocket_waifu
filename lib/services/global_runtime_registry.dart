import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class GlobalRuntimeListener {
  FutureOr<void> onGlobalEnabled();
  FutureOr<void> onGlobalDisabled();
}

class GlobalRuntimeRegistry {
  GlobalRuntimeRegistry._internal();

  static final GlobalRuntimeRegistry instance = GlobalRuntimeRegistry._internal();

  final Set<GlobalRuntimeListener> _listeners = {};

  void register(GlobalRuntimeListener listener) {
    _listeners.add(listener);
  }

  void unregister(GlobalRuntimeListener listener) {
    _listeners.remove(listener);
  }

  void notifyEnabled() {
    for (final listener in List<GlobalRuntimeListener>.from(_listeners)) {
      try {
        listener.onGlobalEnabled();
      } catch (e) {
        debugPrint('GlobalRuntimeRegistry enable listener error: $e');
      }
    }
  }

  void notifyDisabled() {
    for (final listener in List<GlobalRuntimeListener>.from(_listeners)) {
      try {
        listener.onGlobalDisabled();
      } catch (e) {
        debugPrint('GlobalRuntimeRegistry disable listener error: $e');
      }
    }
  }

  GlobalRuntimeListener registerCancelable(VoidCallback cancel) {
    final listener = _CancelableListener(cancel);
    register(listener);
    return listener;
  }
}

class _CancelableListener implements GlobalRuntimeListener {
  _CancelableListener(this._cancel);

  final VoidCallback _cancel;

  @override
  void onGlobalDisabled() {
    _cancel();
  }

  @override
  void onGlobalEnabled() {}
}
