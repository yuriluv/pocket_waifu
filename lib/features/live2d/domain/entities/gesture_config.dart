// ============================================================================
// 제스처 설정 (Gesture Configuration)
// ============================================================================
// 제스처와 동작 매핑을 위한 설정 구조입니다.
// 현재는 기본 틀만 정의하고, 실제 제스처 인식 로직은 추후 구현합니다.
// ============================================================================

import 'interaction_event.dart';

/// 제스처에 매핑될 동작 유형
enum GestureActionType {
  /// 모션 재생
  playMotion,
  
  /// 표정 설정
  setExpression,
  
  /// 랜덤 표정
  randomExpression,
  
  /// 외부로 신호 전송 (다른 앱 기능 호출)
  sendSignal,
  
  /// 아무 동작 없음
  none,
}

/// 제스처 → 동작 매핑
/// 
/// 특정 제스처가 감지되었을 때 어떤 동작을 수행할지 정의합니다.
class GestureActionMapping {
  /// 트리거가 되는 제스처 유형
  final InteractionType gesture;
  
  /// 수행할 동작 유형
  final GestureActionType actionType;
  
  /// 모션 그룹 이름 (playMotion일 때)
  final String? motionGroup;
  
  /// 모션 인덱스 (playMotion일 때)
  final int? motionIndex;
  
  /// 표정 ID (setExpression일 때)
  final String? expressionId;
  
  /// 신호 이름 (sendSignal일 때)
  final String? signalName;
  
  /// 신호 데이터 (sendSignal일 때)
  final Map<String, dynamic>? signalData;

  const GestureActionMapping({
    required this.gesture,
    required this.actionType,
    this.motionGroup,
    this.motionIndex,
    this.expressionId,
    this.signalName,
    this.signalData,
  });

  /// 모션 재생 매핑 생성
  factory GestureActionMapping.motion({
    required InteractionType gesture,
    required String group,
    required int index,
  }) {
    return GestureActionMapping(
      gesture: gesture,
      actionType: GestureActionType.playMotion,
      motionGroup: group,
      motionIndex: index,
    );
  }

  /// 표정 설정 매핑 생성
  factory GestureActionMapping.expression({
    required InteractionType gesture,
    required String expressionId,
  }) {
    return GestureActionMapping(
      gesture: gesture,
      actionType: GestureActionType.setExpression,
      expressionId: expressionId,
    );
  }

  /// 신호 전송 매핑 생성
  factory GestureActionMapping.signal({
    required InteractionType gesture,
    required String signalName,
    Map<String, dynamic>? data,
  }) {
    return GestureActionMapping(
      gesture: gesture,
      actionType: GestureActionType.sendSignal,
      signalName: signalName,
      signalData: data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gesture': gesture.name,
      'actionType': actionType.name,
      if (motionGroup != null) 'motionGroup': motionGroup,
      if (motionIndex != null) 'motionIndex': motionIndex,
      if (expressionId != null) 'expressionId': expressionId,
      if (signalName != null) 'signalName': signalName,
      if (signalData != null) 'signalData': signalData,
    };
  }

  factory GestureActionMapping.fromJson(Map<String, dynamic> json) {
    return GestureActionMapping(
      gesture: InteractionType.values.firstWhere(
        (e) => e.name == json['gesture'],
        orElse: () => InteractionType.unknown,
      ),
      actionType: GestureActionType.values.firstWhere(
        (e) => e.name == json['actionType'],
        orElse: () => GestureActionType.none,
      ),
      motionGroup: json['motionGroup'] as String?,
      motionIndex: json['motionIndex'] as int?,
      expressionId: json['expressionId'] as String?,
      signalName: json['signalName'] as String?,
      signalData: json['signalData'] as Map<String, dynamic>?,
    );
  }
}

/// 제스처 설정
/// 
/// 어떤 제스처 인식을 활성화할지, 각 제스처에 어떤 동작을 매핑할지 설정합니다.
/// 현재는 기본 틀만 제공하고, 실제 설정 UI와 저장/로드는 추후 구현합니다.
class GestureConfig {
  /// 탭 반응 활성화
  final bool enableTapReaction;
  
  /// 더블탭 반응 활성화
  final bool enableDoubleTapReaction;
  
  /// 롱프레스 반응 활성화
  final bool enableLongPressReaction;
  
  /// 드래그 패턴 인식 활성화 (추후 구현)
  final bool enableDragPatterns;
  
  /// 영역별 터치 감지 활성화 (추후 구현)
  final bool enableAreaTouch;
  
  /// 제스처 → 동작 매핑 목록
  final List<GestureActionMapping> actionMappings;

  const GestureConfig({
    this.enableTapReaction = true,
    this.enableDoubleTapReaction = true,
    this.enableLongPressReaction = true,
    this.enableDragPatterns = false,  // 추후 활성화
    this.enableAreaTouch = false,      // 추후 활성화
    this.actionMappings = const [],
  });

  /// 기본 설정
  factory GestureConfig.defaults() => const GestureConfig();

  GestureConfig copyWith({
    bool? enableTapReaction,
    bool? enableDoubleTapReaction,
    bool? enableLongPressReaction,
    bool? enableDragPatterns,
    bool? enableAreaTouch,
    List<GestureActionMapping>? actionMappings,
  }) {
    return GestureConfig(
      enableTapReaction: enableTapReaction ?? this.enableTapReaction,
      enableDoubleTapReaction: enableDoubleTapReaction ?? this.enableDoubleTapReaction,
      enableLongPressReaction: enableLongPressReaction ?? this.enableLongPressReaction,
      enableDragPatterns: enableDragPatterns ?? this.enableDragPatterns,
      enableAreaTouch: enableAreaTouch ?? this.enableAreaTouch,
      actionMappings: actionMappings ?? this.actionMappings,
    );
  }

  /// 특정 제스처에 매핑된 동작 찾기
  GestureActionMapping? getMappingFor(InteractionType gesture) {
    try {
      return actionMappings.firstWhere((m) => m.gesture == gesture);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'enableTapReaction': enableTapReaction,
      'enableDoubleTapReaction': enableDoubleTapReaction,
      'enableLongPressReaction': enableLongPressReaction,
      'enableDragPatterns': enableDragPatterns,
      'enableAreaTouch': enableAreaTouch,
      'actionMappings': actionMappings.map((e) => e.toJson()).toList(),
    };
  }

  factory GestureConfig.fromJson(Map<String, dynamic> json) {
    return GestureConfig(
      enableTapReaction: json['enableTapReaction'] as bool? ?? true,
      enableDoubleTapReaction: json['enableDoubleTapReaction'] as bool? ?? true,
      enableLongPressReaction: json['enableLongPressReaction'] as bool? ?? true,
      enableDragPatterns: json['enableDragPatterns'] as bool? ?? false,
      enableAreaTouch: json['enableAreaTouch'] as bool? ?? false,
      actionMappings: (json['actionMappings'] as List<dynamic>?)
          ?.map((e) => GestureActionMapping.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
