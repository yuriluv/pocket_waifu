// ============================================================================
// ============================================================================
// ============================================================================

import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';

/// 
class InteractionMapping {
  final InteractionType trigger;
  
  final InteractionResponse response;
  
  final bool enabled;
  
  final int cooldownMs;
  
  final InteractionCondition? condition;
  
  final int priority;

  const InteractionMapping({
    required this.trigger,
    required this.response,
    this.enabled = true,
    this.cooldownMs = 0,
    this.condition,
    this.priority = 0,
  });

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

/// 
class InteractionCondition {
  final String? modelPath;
  
  final String? requiredState;
  
  final TimeCondition? timeCondition;

  const InteractionCondition({
    this.modelPath,
    this.requiredState,
    this.timeCondition,
  });

  bool evaluate({String? currentModel, String? currentState}) {
    if (modelPath != null && currentModel != modelPath) {
      return false;
    }
    
    if (requiredState != null && currentState != requiredState) {
      return false;
    }
    
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

class TimeCondition {
  final int startHour;
  
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
