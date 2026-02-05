// ============================================================================
// 상호작용 응답 (Interaction Response)
// ============================================================================
// 상호작용 이벤트에 대한 응답 액션을 정의합니다.
// 제스처 감지 후 어떤 동작을 수행할지 결정합니다.
// ============================================================================

/// 응답 액션 유형
enum ResponseAction {
  /// 모션 재생
  playMotion,
  
  /// 표정 설정
  setExpression,
  
  /// 랜덤 표정
  randomExpression,
  
  /// 랜덤 모션
  randomMotion,
  
  /// 소리 재생 (미래 확장용)
  playSound,
  
  /// 말풍선 표시 (미래 확장용)
  showBubble,
  
  /// 진동 피드백
  vibrate,
  
  /// Flutter 쪽으로 신호 전송
  sendSignalToFlutter,
  
  /// 복합 액션 (여러 액션 조합)
  composite,
  
  /// 아무 동작 없음
  none,
}

/// 상호작용 응답
/// 
/// 특정 상호작용 이벤트에 대해 어떤 동작을 수행할지 정의합니다.
class InteractionResponse {
  /// 응답 액션 유형
  final ResponseAction action;
  
  /// 모션 그룹 (playMotion일 때)
  final String? motionGroup;
  
  /// 모션 인덱스 (playMotion일 때)
  final int? motionIndex;
  
  /// 모션 우선순위 (playMotion일 때)
  final int? motionPriority;
  
  /// 표정 ID (setExpression일 때)
  final String? expressionId;
  
  /// 사운드 파일 경로 (playSound일 때)
  final String? soundPath;
  
  /// 말풍선 텍스트 (showBubble일 때)
  final String? bubbleText;
  
  /// 진동 지속시간 ms (vibrate일 때)
  final int? vibrateDuration;
  
  /// 신호 이름 (sendSignalToFlutter일 때)
  final String? signalName;
  
  /// 신호 데이터 (sendSignalToFlutter일 때)
  final Map<String, dynamic>? signalData;
  
  /// 복합 액션 목록 (composite일 때)
  final List<InteractionResponse>? compositeActions;
  
  /// 지연 시간 (ms)
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

  /// 모션 재생 응답 생성
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

  /// 표정 설정 응답 생성
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

  /// 랜덤 표정 응답 생성
  factory InteractionResponse.randomExpression({int delayMs = 0}) {
    return InteractionResponse(
      action: ResponseAction.randomExpression,
      delayMs: delayMs,
    );
  }

  /// 랜덤 모션 응답 생성
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

  /// 진동 피드백 응답 생성
  factory InteractionResponse.vibrate({int durationMs = 50}) {
    return InteractionResponse(
      action: ResponseAction.vibrate,
      vibrateDuration: durationMs,
    );
  }

  /// 신호 전송 응답 생성
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

  /// 복합 액션 응답 생성
  factory InteractionResponse.composite(List<InteractionResponse> actions) {
    return InteractionResponse(
      action: ResponseAction.composite,
      compositeActions: actions,
    );
  }

  /// 아무 동작 없음 응답
  static const InteractionResponse none = InteractionResponse(
    action: ResponseAction.none,
  );

  /// JSON 직렬화
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

  /// JSON 역직렬화
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
