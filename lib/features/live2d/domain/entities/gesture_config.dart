// ============================================================================
// ============================================================================
// ============================================================================

import 'interaction_event.dart';

enum GestureActionType {
  playMotion,
  
  setExpression,
  
  randomExpression,
  
  sendSignal,
  
  none,
}

/// 
class GestureActionMapping {
  final InteractionType gesture;
  
  final GestureActionType actionType;
  
  final String? motionGroup;
  
  final int? motionIndex;
  
  final String? expressionId;
  
  final String? signalName;
  
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

/// 
class GestureConfig {
  final bool enableTapReaction;
  
  final bool enableDoubleTapReaction;
  
  final bool enableLongPressReaction;
  
  final bool enableDragPatterns;
  
  final bool enableAreaTouch;
  
  final List<GestureActionMapping> actionMappings;

  const GestureConfig({
    this.enableTapReaction = true,
    this.enableDoubleTapReaction = true,
    this.enableLongPressReaction = true,
    this.enableDragPatterns = false,
    this.enableAreaTouch = false,
    this.actionMappings = const [],
  });

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
