// ============================================================================
// ============================================================================
// ============================================================================

import '../models/interaction_mapping.dart';
import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';

class InteractionConfig {
  final List<InteractionMapping> mappings;
  
  final bool enableTouchFeedback;
  
  final bool autoReactionEnabled;
  
  final int globalCooldownMs;
  
  final bool enableTouchReaction;
  
  final bool enableSwipeDetection;
  
  final bool enableHeadPatDetection;
  
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

  static List<InteractionMapping> _defaultMappings() {
    return [
      InteractionMapping.simple(
        trigger: InteractionType.tap,
        response: InteractionResponse.motion(group: 'tap', index: 0),
      ),
      
      InteractionMapping.simple(
        trigger: InteractionType.doubleTap,
        response: InteractionResponse.randomExpression(),
      ),
      
      InteractionMapping.simple(
        trigger: InteractionType.longPress,
        response: InteractionResponse.motion(group: 'special', index: 0, priority: 3),
      ),
      
      InteractionMapping.simple(
        trigger: InteractionType.headPat,
        response: InteractionResponse.composite([
          InteractionResponse.expression(expressionId: 'happy'),
          InteractionResponse.motion(group: 'happy', index: 0, delayMs: 100),
        ]),
      ),
      
      InteractionMapping.simple(
        trigger: InteractionType.swipeUp,
        response: InteractionResponse.motion(group: 'greet', index: 0),
      ),
      
      InteractionMapping.simple(
        trigger: InteractionType.swipeDown,
        response: InteractionResponse.motion(group: 'bow', index: 0),
      ),
    ];
  }

  InteractionMapping? getMappingFor(InteractionType trigger) {
    try {
      final enabledMappings = mappings
          .where((m) => m.trigger == trigger && m.enabled)
          .toList();
      
      if (enabledMappings.isEmpty) return null;
      
      enabledMappings.sort((a, b) => b.priority.compareTo(a.priority));
      return enabledMappings.first;
    } catch (e) {
      return null;
    }
  }

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

  InteractionConfig addMapping(InteractionMapping mapping) {
    return copyWith(mappings: [...mappings, mapping]);
  }

  InteractionConfig removeMapping(InteractionMapping mapping) {
    return copyWith(
      mappings: mappings.where((m) => m != mapping).toList(),
    );
  }

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
