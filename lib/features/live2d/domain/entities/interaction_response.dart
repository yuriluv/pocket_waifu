// ============================================================================
// ============================================================================
// ============================================================================

enum ResponseAction {
  playMotion,
  
  setExpression,
  
  randomExpression,
  
  randomMotion,
  
  playSound,
  
  showBubble,
  
  vibrate,
  
  sendSignalToFlutter,
  
  composite,
  
  none,
}

/// 
class InteractionResponse {
  final ResponseAction action;
  
  final String? motionGroup;
  
  final int? motionIndex;
  
  final int? motionPriority;
  
  final String? expressionId;
  
  final String? soundPath;
  
  final String? bubbleText;
  
  final int? vibrateDuration;
  
  final String? signalName;
  
  final Map<String, dynamic>? signalData;
  
  final List<InteractionResponse>? compositeActions;
  
  final int delayMs;

  const InteractionResponse({
    required this.action,
    this.motionGroup,
    this.motionIndex,
    this.motionPriority,
    this.expressionId,
    this.soundPath,
    this.bubbleText,
    this.vibrateDuration,
    this.signalName,
    this.signalData,
    this.compositeActions,
    this.delayMs = 0,
  });

  factory InteractionResponse.motion({
    required String group,
    int index = 0,
    int priority = 2,
    int delayMs = 0,
  }) {
    return InteractionResponse(
      action: ResponseAction.playMotion,
      motionGroup: group,
      motionIndex: index,
      motionPriority: priority,
      delayMs: delayMs,
    );
  }

  factory InteractionResponse.expression({
    required String expressionId,
    int delayMs = 0,
  }) {
    return InteractionResponse(
      action: ResponseAction.setExpression,
      expressionId: expressionId,
      delayMs: delayMs,
    );
  }

  factory InteractionResponse.randomExpression({int delayMs = 0}) {
    return InteractionResponse(
      action: ResponseAction.randomExpression,
      delayMs: delayMs,
    );
  }

  factory InteractionResponse.randomMotion({
    String? fromGroup,
    int delayMs = 0,
  }) {
    return InteractionResponse(
      action: ResponseAction.randomMotion,
      motionGroup: fromGroup,
      delayMs: delayMs,
    );
  }

  factory InteractionResponse.vibrate({int durationMs = 50}) {
    return InteractionResponse(
      action: ResponseAction.vibrate,
      vibrateDuration: durationMs,
    );
  }

  factory InteractionResponse.signal({
    required String signalName,
    Map<String, dynamic>? data,
  }) {
    return InteractionResponse(
      action: ResponseAction.sendSignalToFlutter,
      signalName: signalName,
      signalData: data,
    );
  }

  factory InteractionResponse.composite(List<InteractionResponse> actions) {
    return InteractionResponse(
      action: ResponseAction.composite,
      compositeActions: actions,
    );
  }

  static const InteractionResponse none = InteractionResponse(
    action: ResponseAction.none,
  );

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      if (motionGroup != null) 'motionGroup': motionGroup,
      if (motionIndex != null) 'motionIndex': motionIndex,
      if (motionPriority != null) 'motionPriority': motionPriority,
      if (expressionId != null) 'expressionId': expressionId,
      if (soundPath != null) 'soundPath': soundPath,
      if (bubbleText != null) 'bubbleText': bubbleText,
      if (vibrateDuration != null) 'vibrateDuration': vibrateDuration,
      if (signalName != null) 'signalName': signalName,
      if (signalData != null) 'signalData': signalData,
      if (compositeActions != null)
        'compositeActions': compositeActions!.map((a) => a.toJson()).toList(),
      if (delayMs > 0) 'delayMs': delayMs,
    };
  }

  factory InteractionResponse.fromJson(Map<String, dynamic> json) {
    final actionStr = json['action'] as String?;
    final action = ResponseAction.values.firstWhere(
      (e) => e.name == actionStr,
      orElse: () => ResponseAction.none,
    );

    List<InteractionResponse>? compositeActions;
    if (json['compositeActions'] != null) {
      compositeActions = (json['compositeActions'] as List)
          .map((e) => InteractionResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return InteractionResponse(
      action: action,
      motionGroup: json['motionGroup'] as String?,
      motionIndex: json['motionIndex'] as int?,
      motionPriority: json['motionPriority'] as int?,
      expressionId: json['expressionId'] as String?,
      soundPath: json['soundPath'] as String?,
      bubbleText: json['bubbleText'] as String?,
      vibrateDuration: json['vibrateDuration'] as int?,
      signalName: json['signalName'] as String?,
      signalData: json['signalData'] as Map<String, dynamic>?,
      compositeActions: compositeActions,
      delayMs: json['delayMs'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    switch (action) {
      case ResponseAction.playMotion:
        return 'PlayMotion($motionGroup[$motionIndex])';
      case ResponseAction.setExpression:
        return 'SetExpression($expressionId)';
      case ResponseAction.randomExpression:
        return 'RandomExpression';
      case ResponseAction.randomMotion:
        return 'RandomMotion(${motionGroup ?? "any"})';
      case ResponseAction.vibrate:
        return 'Vibrate(${vibrateDuration}ms)';
      case ResponseAction.sendSignalToFlutter:
        return 'Signal($signalName)';
      case ResponseAction.composite:
        return 'Composite(${compositeActions?.length ?? 0} actions)';
      default:
        return action.name;
    }
  }
}
