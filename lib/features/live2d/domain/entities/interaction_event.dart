// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:ui';

/// 
enum InteractionType {
  tap,
  doubleTap,
  longPress,
  
  swipeUp,
  swipeDown,
  swipeLeft,
  swipeRight,
  circleCW,
  circleCCW,
  headPat,
  zigzag,
  
  headTouch,
  faceTouch,
  bodyTouch,
  
  overlayShown,
  overlayHidden,
  modelLoaded,
  modelUnloaded,
  motionStarted,
  motionFinished,
  notificationSessionSync,
  notificationTouchThroughToggled,
  displayStateChanged,
  
  externalCommand,
  
  unknown,
}

/// 
class InteractionEvent {
  final InteractionType type;
  
  final Offset? position;
  
  final Map<String, dynamic>? extras;
  
  final DateTime timestamp;

  const InteractionEvent({
    required this.type,
    this.position,
    this.extras,
    required this.timestamp,
  });

  factory InteractionEvent.now({
    required InteractionType type,
    Offset? position,
    Map<String, dynamic>? extras,
  }) {
    return InteractionEvent(
      type: type,
      position: position,
      extras: extras,
      timestamp: DateTime.now(),
    );
  }

  factory InteractionEvent.fromMap(Map<String, dynamic> map) {
    return InteractionEvent(
      type: _parseType(map['type'] as String?),
      position: _parsePosition(map),
      extras: _parseExtras(map['extras']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (position != null) 'x': position!.dx,
      if (position != null) 'y': position!.dy,
      if (extras != null) 'extras': extras,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  static InteractionType _parseType(String? typeStr) {
    if (typeStr == null) return InteractionType.unknown;
    
    try {
      return InteractionType.values.firstWhere(
        (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
        orElse: () => InteractionType.unknown,
      );
    } catch (e) {
      return InteractionType.unknown;
    }
  }

  static Offset? _parsePosition(Map<String, dynamic> map) {
    final x = map['x'];
    final y = map['y'];
    
    if (x != null && y != null) {
      return Offset(
        (x as num).toDouble(),
        (y as num).toDouble(),
      );
    }
    return null;
  }

  static Map<String, dynamic>? _parseExtras(dynamic extras) {
    if (extras is! Map) return null;
    return extras.map((key, value) => MapEntry(key.toString(), value));
  }

  factory InteractionEvent.command(String commandName, {
    Map<String, dynamic>? params,
  }) {
    return InteractionEvent.now(
      type: InteractionType.externalCommand,
      extras: {
        'command': commandName,
        if (params != null) ...params,
      },
    );
  }

  factory InteractionEvent.system(InteractionType type, {
    Map<String, dynamic>? data,
  }) {
    return InteractionEvent.now(
      type: type,
      extras: data,
    );
  }

  @override
  String toString() {
    return 'InteractionEvent('
        'type: $type, '
        'position: $position, '
        'extras: $extras, '
        'timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InteractionEvent &&
        other.type == type &&
        other.position == position &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(type, position, timestamp);
}

/// 
typedef InteractionHandler = void Function(InteractionEvent event);

/// 
abstract class ExternalInteractionListener {
  void onInteraction(InteractionEvent event);
}
