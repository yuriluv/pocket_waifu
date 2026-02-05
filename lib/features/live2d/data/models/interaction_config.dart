// ============================================================================
// 상호작용 설정 (Interaction Config)
// ============================================================================
// 전체 상호작용 시스템의 설정을 관리합니다.
// 제스처 인식, 반응 매핑, 외부 연동 등의 설정을 포함합니다.
// ============================================================================

import '../models/interaction_mapping.dart';
import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';

/// 상호작용 설정
class InteractionConfig {
  /// 상호작용 매핑 목록
  final List<InteractionMapping> mappings;
  
  /// 터치 피드백 활성화 (진동)
  final bool enableTouchFeedback;
  
  /// 자동 반응 활성화
  final bool autoReactionEnabled;
  
  /// 반응 쿨다운 (ms) - 연속 반응 방지
  final int globalCooldownMs;
  
  /// 터치 반응 활성화
  final bool enableTouchReaction;
  
  /// 스와이프 인식 활성화
  final bool enableSwipeDetection;
  
  /// 머리 쓰다듬기 인식 활성화
  final bool enableHeadPatDetection;
  
  /// 외부 신호 수신 활성화
  final bool enableExternalSignals;

  const InteractionConfig({
    this.mappings = const [],
    this.enableTouchFeedback = true,
    this.autoReactionEnabled = true,
    this.globalCooldownMs = 500,
    this.enableTouchReaction = true,
    this.enableSwipeDetection = true,
    this.enableHeadPatDetection = true,
    this.enableExternalSignals = true,
  });

  /// 기본 설정
  factory InteractionConfig.defaults() {
    return InteractionConfig(
      mappings: InteractionConfig._defaultMappings(),
      enableTouchFeedback: true,
      autoReactionEnabled: true,
      globalCooldownMs: 500,
      enableTouchReaction: true,
      enableSwipeDetection: true,
      enableHeadPatDetection: true,
      enableExternalSignals: true,
    );
  }

  /// 기본 매핑 목록
  static List<InteractionMapping> _defaultMappings() {
    return [
      // 탭 → 탭 반응 모션
      InteractionMapping.simple(
        trigger: InteractionType.tap,
        response: InteractionResponse.motion(group: 'tap', index: 0),
      ),
      
      // 더블탭 → 랜덤 표정
      InteractionMapping.simple(
        trigger: InteractionType.doubleTap,
        response: InteractionResponse.randomExpression(),
      ),
      
      // 롱프레스 → 특별 모션
      InteractionMapping.simple(
        trigger: InteractionType.longPress,
        response: InteractionResponse.motion(group: 'special', index: 0, priority: 3),
      ),
      
      // 머리 쓰다듬기 → 좋아하는 반응
      InteractionMapping.simple(
        trigger: InteractionType.headPat,
        response: InteractionResponse.composite([
          InteractionResponse.expression(expressionId: 'happy'),
          InteractionResponse.motion(group: 'happy', index: 0, delayMs: 100),
        ]),
      ),
      
      // 스와이프 위 → 인사 모션
      InteractionMapping.simple(
        trigger: InteractionType.swipeUp,
        response: InteractionResponse.motion(group: 'greet', index: 0),
      ),
      
      // 스와이프 아래 → 숙이기 모션
      InteractionMapping.simple(
        trigger: InteractionType.swipeDown,
        response: InteractionResponse.motion(group: 'bow', index: 0),
      ),
    ];
  }

  /// 특정 트리거에 대한 매핑 찾기
  InteractionMapping? getMappingFor(InteractionType trigger) {
    try {
      final enabledMappings = mappings
          .where((m) => m.trigger == trigger && m.enabled)
          .toList();
      
      if (enabledMappings.isEmpty) return null;
      
      // 우선순위가 높은 것 선택
      enabledMappings.sort((a, b) => b.priority.compareTo(a.priority));
      return enabledMappings.first;
    } catch (e) {
      return null;
    }
  }

  /// 특정 트리거에 대한 모든 매핑 찾기
  List<InteractionMapping> getAllMappingsFor(InteractionType trigger) {
    return mappings
        .where((m) => m.trigger == trigger && m.enabled)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  InteractionConfig copyWith({
    List<InteractionMapping>? mappings,
    bool? enableTouchFeedback,
    bool? autoReactionEnabled,
    int? globalCooldownMs,
    bool? enableTouchReaction,
    bool? enableSwipeDetection,
    bool? enableHeadPatDetection,
    bool? enableExternalSignals,
  }) {
    return InteractionConfig(
      mappings: mappings ?? this.mappings,
      enableTouchFeedback: enableTouchFeedback ?? this.enableTouchFeedback,
      autoReactionEnabled: autoReactionEnabled ?? this.autoReactionEnabled,
      globalCooldownMs: globalCooldownMs ?? this.globalCooldownMs,
      enableTouchReaction: enableTouchReaction ?? this.enableTouchReaction,
      enableSwipeDetection: enableSwipeDetection ?? this.enableSwipeDetection,
      enableHeadPatDetection: enableHeadPatDetection ?? this.enableHeadPatDetection,
      enableExternalSignals: enableExternalSignals ?? this.enableExternalSignals,
    );
  }

  /// 매핑 추가
  InteractionConfig addMapping(InteractionMapping mapping) {
    return copyWith(mappings: [...mappings, mapping]);
  }

  /// 매핑 제거
  InteractionConfig removeMapping(InteractionMapping mapping) {
    return copyWith(
      mappings: mappings.where((m) => m != mapping).toList(),
    );
  }

  /// 특정 트리거의 매핑 업데이트
  InteractionConfig updateMapping(
    InteractionType trigger,
    InteractionResponse newResponse,
  ) {
    return copyWith(
      mappings: mappings.map((m) {
        if (m.trigger == trigger) {
          return m.copyWith(response: newResponse);
        }
        return m;
      }).toList(),
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'mappings': mappings.map((m) => m.toJson()).toList(),
      'enableTouchFeedback': enableTouchFeedback,
      'autoReactionEnabled': autoReactionEnabled,
      'globalCooldownMs': globalCooldownMs,
      'enableTouchReaction': enableTouchReaction,
      'enableSwipeDetection': enableSwipeDetection,
      'enableHeadPatDetection': enableHeadPatDetection,
      'enableExternalSignals': enableExternalSignals,
    };
  }

  /// JSON 역직렬화
  factory InteractionConfig.fromJson(Map<String, dynamic> json) {
    return InteractionConfig(
      mappings: (json['mappings'] as List<dynamic>?)
              ?.map((m) => InteractionMapping.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      enableTouchFeedback: json['enableTouchFeedback'] as bool? ?? true,
      autoReactionEnabled: json['autoReactionEnabled'] as bool? ?? true,
      globalCooldownMs: json['globalCooldownMs'] as int? ?? 500,
      enableTouchReaction: json['enableTouchReaction'] as bool? ?? true,
      enableSwipeDetection: json['enableSwipeDetection'] as bool? ?? true,
      enableHeadPatDetection: json['enableHeadPatDetection'] as bool? ?? true,
      enableExternalSignals: json['enableExternalSignals'] as bool? ?? true,
    );
  }
}
