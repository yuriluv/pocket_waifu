// ============================================================================
// 상호작용 매핑 설정 (Interaction Mapping)
// ============================================================================
// 상호작용 이벤트와 응답 액션 간의 매핑을 정의합니다.
// 사용자 설정에 따라 제스처별 반응을 커스터마이징할 수 있습니다.
// ============================================================================

import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';

/// 상호작용 매핑
/// 
/// 특정 상호작용 이벤트가 발생했을 때 어떤 응답을 수행할지 정의합니다.
class InteractionMapping {
  /// 트리거가 되는 상호작용 유형
  final InteractionType trigger;
  
  /// 수행할 응답 액션
  final InteractionResponse response;
  
  /// 매핑 활성화 여부
  final bool enabled;
  
  /// 쿨다운 시간 (ms) - 같은 트리거가 연속 발생 시 무시
  final int cooldownMs;
  
  /// 조건 (특정 모델, 상태에서만 동작)
  final InteractionCondition? condition;
  
  /// 우선순위 (높을수록 먼저 처리)
  final int priority;

  const InteractionMapping({
    required this.trigger,
    required this.response,
    this.enabled = true,
    this.cooldownMs = 0,
    this.condition,
    this.priority = 0,
  });

  /// 간단한 매핑 생성
  factory InteractionMapping.simple({
    required InteractionType trigger,
    required InteractionResponse response,
    bool enabled = true,
  }) {
    return InteractionMapping(
      trigger: trigger,
      response: response,
      enabled: enabled,
    );
  }

  /// 탭 → 모션 매핑
  factory InteractionMapping.tapToMotion({
    required String motionGroup,
    int motionIndex = 0,
    bool enabled = true,
  }) {
    return InteractionMapping(
      trigger: InteractionType.tap,
      response: InteractionResponse.motion(
        group: motionGroup,
        index: motionIndex,
      ),
      enabled: enabled,
    );
  }

  /// 더블탭 → 표정 매핑
  factory InteractionMapping.doubleTapToExpression({
    required String expressionId,
    bool enabled = true,
  }) {
    return InteractionMapping(
      trigger: InteractionType.doubleTap,
      response: InteractionResponse.expression(expressionId: expressionId),
      enabled: enabled,
    );
  }

  /// 롱프레스 → 신호 매핑
  factory InteractionMapping.longPressToSignal({
    required String signalName,
    Map<String, dynamic>? data,
    bool enabled = true,
  }) {
    return InteractionMapping(
      trigger: InteractionType.longPress,
      response: InteractionResponse.signal(signalName: signalName, data: data),
      enabled: enabled,
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'trigger': trigger.name,
      'response': response.toJson(),
      'enabled': enabled,
      'cooldownMs': cooldownMs,
      if (condition != null) 'condition': condition!.toJson(),
      'priority': priority,
    };
  }

  /// JSON 역직렬화
  factory InteractionMapping.fromJson(Map<String, dynamic> json) {
    return InteractionMapping(
      trigger: InteractionType.values.firstWhere(
        (e) => e.name == json['trigger'],
        orElse: () => InteractionType.unknown,
      ),
      response: InteractionResponse.fromJson(
        json['response'] as Map<String, dynamic>,
      ),
      enabled: json['enabled'] as bool? ?? true,
      cooldownMs: json['cooldownMs'] as int? ?? 0,
      condition: json['condition'] != null
          ? InteractionCondition.fromJson(
              json['condition'] as Map<String, dynamic>,
            )
          : null,
      priority: json['priority'] as int? ?? 0,
    );
  }

  InteractionMapping copyWith({
    InteractionType? trigger,
    InteractionResponse? response,
    bool? enabled,
    int? cooldownMs,
    InteractionCondition? condition,
    int? priority,
  }) {
    return InteractionMapping(
      trigger: trigger ?? this.trigger,
      response: response ?? this.response,
      enabled: enabled ?? this.enabled,
      cooldownMs: cooldownMs ?? this.cooldownMs,
      condition: condition ?? this.condition,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() {
    return 'InteractionMapping(${trigger.name} → $response, enabled: $enabled)';
  }
}

/// 상호작용 조건
/// 
/// 매핑이 적용되기 위한 조건을 정의합니다.
class InteractionCondition {
  /// 특정 모델에서만 동작 (null이면 모든 모델)
  final String? modelPath;
  
  /// 특정 상태에서만 동작
  final String? requiredState;
  
  /// 시간 조건 (예: 특정 시간대에만)
  final TimeCondition? timeCondition;

  const InteractionCondition({
    this.modelPath,
    this.requiredState,
    this.timeCondition,
  });

  /// 조건 평가
  bool evaluate({String? currentModel, String? currentState}) {
    // 모델 조건 체크
    if (modelPath != null && currentModel != modelPath) {
      return false;
    }
    
    // 상태 조건 체크
    if (requiredState != null && currentState != requiredState) {
      return false;
    }
    
    // 시간 조건 체크
    if (timeCondition != null && !timeCondition!.isInRange(DateTime.now())) {
      return false;
    }
    
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      if (modelPath != null) 'modelPath': modelPath,
      if (requiredState != null) 'requiredState': requiredState,
      if (timeCondition != null) 'timeCondition': timeCondition!.toJson(),
    };
  }

  factory InteractionCondition.fromJson(Map<String, dynamic> json) {
    return InteractionCondition(
      modelPath: json['modelPath'] as String?,
      requiredState: json['requiredState'] as String?,
      timeCondition: json['timeCondition'] != null
          ? TimeCondition.fromJson(json['timeCondition'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 시간 조건
class TimeCondition {
  /// 시작 시간 (0-23)
  final int startHour;
  
  /// 종료 시간 (0-23)
  final int endHour;

  const TimeCondition({
    required this.startHour,
    required this.endHour,
  });

  bool isInRange(DateTime time) {
    final hour = time.hour;
    if (startHour <= endHour) {
      return hour >= startHour && hour < endHour;
    } else {
      // 자정을 넘기는 경우 (예: 22시 ~ 6시)
      return hour >= startHour || hour < endHour;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startHour,
      'endHour': endHour,
    };
  }

  factory TimeCondition.fromJson(Map<String, dynamic> json) {
    return TimeCondition(
      startHour: json['startHour'] as int,
      endHour: json['endHour'] as int,
    );
  }
}
