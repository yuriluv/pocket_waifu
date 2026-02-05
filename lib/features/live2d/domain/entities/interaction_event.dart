// ============================================================================
// 상호작용 이벤트 (Interaction Event)
// ============================================================================
// Live2D 오버레이와의 상호작용 이벤트를 정의합니다.
// 이 구조는 나중에 제스처 인식, 터치 감지, 외부 명령 등을
// 쉽게 확장할 수 있도록 설계되었습니다.
// ============================================================================

import 'dart:ui';

/// 상호작용 유형
/// 
/// 현재는 기본 타입만 정의하고, 나중에 필요에 따라 확장합니다.
/// - 기본 터치: tap, doubleTap, longPress
/// - 드래그 패턴: swipe*, circle*, headPat 등 (추후 확장)
/// - 영역 터치: headTouch, bodyTouch 등 (추후 확장)
/// - 시스템: overlay 상태, 모델 상태
/// - 외부 명령: 다른 앱 기능에서 보내는 신호
enum InteractionType {
  // ========== 기본 터치 (Phase 1 - 기본 틀) ==========
  tap,
  doubleTap,
  longPress,
  
  // ========== 드래그 패턴 (추후 확장) ==========
  swipeUp,
  swipeDown,
  swipeLeft,
  swipeRight,
  circleCW,      // 시계방향 원
  circleCCW,     // 반시계방향 원
  headPat,       // 머리 쓰다듬기 (좌우 반복)
  zigzag,        // 지그재그
  
  // ========== 특수 영역 터치 (추후 확장) ==========
  headTouch,
  faceTouch,
  bodyTouch,
  
  // ========== 시스템 이벤트 ==========
  overlayShown,
  overlayHidden,
  modelLoaded,
  modelUnloaded,
  motionStarted,
  motionFinished,
  
  // ========== 외부 명령 (다른 앱 기능 연동) ==========
  /// 다른 앱 기능(채팅, 알림 등)에서 Live2D에 명령을 보낼 때 사용
  externalCommand,
  
  // ========== 알 수 없음 ==========
  unknown,
}

/// 상호작용 이벤트
/// 
/// Native 측에서 Flutter로 전달되는 이벤트,
/// 또는 Flutter 내부에서 발생하는 이벤트를 표현합니다.
class InteractionEvent {
  /// 이벤트 유형
  final InteractionType type;
  
  /// 터치 위치 (해당되는 경우)
  final Offset? position;
  
  /// 추가 데이터 (명령 파라미터, 패턴 정보 등)
  final Map<String, dynamic>? extras;
  
  /// 이벤트 발생 시각
  final DateTime timestamp;

  const InteractionEvent({
    required this.type,
    this.position,
    this.extras,
    required this.timestamp,
  });

  /// 현재 시각으로 이벤트 생성
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

  /// Map에서 생성 (Platform Channel에서 수신)
  factory InteractionEvent.fromMap(Map<String, dynamic> map) {
    return InteractionEvent(
      type: _parseType(map['type'] as String?),
      position: _parsePosition(map),
      extras: map['extras'] as Map<String, dynamic>?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Map으로 변환 (Platform Channel로 전송)
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (position != null) 'x': position!.dx,
      if (position != null) 'y': position!.dy,
      if (extras != null) 'extras': extras,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// 문자열에서 InteractionType 파싱
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

  /// Map에서 위치 파싱
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

  /// 외부 명령 이벤트 생성 헬퍼
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

  /// 시스템 이벤트 생성 헬퍼
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

/// 상호작용 핸들러 타입 정의
/// 
/// 이벤트를 처리하는 콜백 함수의 시그니처입니다.
typedef InteractionHandler = void Function(InteractionEvent event);

/// 외부 상호작용 리스너 인터페이스
/// 
/// 다른 앱 기능에서 Live2D 이벤트를 수신하기 위한 인터페이스입니다.
abstract class ExternalInteractionListener {
  /// 상호작용 이벤트 수신
  void onInteraction(InteractionEvent event);
}
