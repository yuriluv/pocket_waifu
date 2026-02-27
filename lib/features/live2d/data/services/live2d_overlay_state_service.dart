// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:async';
import '../../domain/entities/interaction_event.dart';
import 'live2d_log_service.dart';
import 'live2d_native_bridge.dart';

class Live2DOverlayState {
  final int containerWidth;
  final int containerHeight;
  final int containerX;
  final int containerY;
  final double relativeScale;
  final double offsetX;
  final double offsetY;
  final int rotationDeg;
  final int screenWidth;
  final int screenHeight;
  final double density;
  final double globalScale;

  const Live2DOverlayState({
    required this.containerWidth,
    required this.containerHeight,
    required this.containerX,
    required this.containerY,
    required this.relativeScale,
    required this.offsetX,
    required this.offsetY,
    required this.rotationDeg,
    required this.screenWidth,
    required this.screenHeight,
    required this.density,
    required this.globalScale,
  });

  factory Live2DOverlayState.fromMap(Map<String, dynamic> map) {
    return Live2DOverlayState(
      containerWidth: (map['containerWidth'] as num?)?.toInt() ?? 0,
      containerHeight: (map['containerHeight'] as num?)?.toInt() ?? 0,
      containerX: (map['containerX'] as num?)?.toInt() ?? 0,
      containerY: (map['containerY'] as num?)?.toInt() ?? 0,
      relativeScale: (map['relativeScale'] as num?)?.toDouble() ?? 1.0,
      offsetX: (map['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (map['offsetY'] as num?)?.toDouble() ?? 0.0,
      rotationDeg: (map['rotationDeg'] as num?)?.toInt() ?? 0,
      screenWidth: (map['screenWidth'] as num?)?.toInt() ?? 0,
      screenHeight: (map['screenHeight'] as num?)?.toInt() ?? 0,
      density: (map['density'] as num?)?.toDouble() ?? 1.0,
      globalScale: (map['globalScale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class Live2DOverlayStateService {
  static const String _tag = 'OverlayStateService';

  static final Live2DOverlayStateService _instance =
      Live2DOverlayStateService._internal();
  factory Live2DOverlayStateService() => _instance;
  Live2DOverlayStateService._internal();

  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  StreamSubscription<InteractionEvent>? _subscription;

  Live2DOverlayState? _lastState;
  Live2DOverlayState? get lastState => _lastState;

  void attach() {
    _subscription ??= _bridge.eventStream.listen(_handleEvent);
  }

  void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleEvent(InteractionEvent event) {
    if (event.type == InteractionType.displayStateChanged) {
      final extras = event.extras;
      if (extras != null) {
        _lastState = Live2DOverlayState.fromMap(extras);
      }
    }
  }

  Future<Live2DOverlayState?> fetchCurrentState() async {
    try {
      final state = await _bridge.getDisplayState();
      if (state.isEmpty) return _lastState;
      _lastState = Live2DOverlayState.fromMap(state);
      return _lastState;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 상태 조회 실패', error: e);
      return _lastState;
    }
  }
}
