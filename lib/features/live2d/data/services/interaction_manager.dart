// ============================================================================
// 상호작용 관리자 (Interaction Manager)
// ============================================================================
// Live2D 상호작용 이벤트를 처리하고 응답을 실행합니다.
// 제스처 → 반응 매핑, 외부 연동 API를 제공합니다.
// ============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';
import '../models/interaction_config.dart';
import 'live2d_native_bridge.dart';
import 'live2d_log_service.dart';

/// 상호작용 관리자
/// 
/// Live2D 상호작용 이벤트를 처리하고, 설정된 매핑에 따라 반응을 실행합니다.
/// 외부 앱 기능과의 연동 인터페이스도 제공합니다.
class InteractionManager {
  static const String _tag = 'InteractionManager';
  
  // 싱글톤 패턴
  static final InteractionManager _instance = InteractionManager._internal();
  factory InteractionManager() => _instance;
  InteractionManager._internal();
  
  // 의존성
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  // 설정
  InteractionConfig _config = InteractionConfig.defaults();
  InteractionConfig get config => _config;
  
  // 이벤트 스트림
  final StreamController<InteractionEvent> _eventController = 
      StreamController<InteractionEvent>.broadcast();
  
  /// 상호작용 이벤트 스트림
  Stream<InteractionEvent> get eventStream => _eventController.stream;
  
  // 외부 리스너
  final List<ExternalInteractionListener> _externalListeners = [];
  
  // 쿨다운 관리
  final Map<InteractionType, DateTime> _lastTriggerTimes = {};
  
  // 상태
  bool _isInitialized = false;
  String? _currentModelPath;
  
  // ============================================================================
  // 초기화 / 정리
  // ============================================================================
  
  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    live2dLog.info(_tag, 'InteractionManager 초기화');
    
    // 브릿지에 이벤트 핸들러 등록
    _bridge.addEventHandler(_handleNativeEvent);
    
    _isInitialized = true;
  }
  
  /// 정리
  void dispose() {
    _bridge.removeEventHandler(_handleNativeEvent);
    _externalListeners.clear();
    _lastTriggerTimes.clear();
    _eventController.close();
    _isInitialized = false;
    live2dLog.info(_tag, 'InteractionManager 정리됨');
  }
  
  // ============================================================================
  // 설정 관리
  // ============================================================================
  
  /// 설정 업데이트
  void updateConfig(InteractionConfig newConfig) {
    _config = newConfig;
    live2dLog.debug(_tag, '설정 업데이트됨', details: '매핑 수: ${newConfig.mappings.length}');
  }
  
  /// 현재 모델 설정
  void setCurrentModel(String? modelPath) {
    _currentModelPath = modelPath;
  }
  
  // ============================================================================
  // 이벤트 처리
  // ============================================================================
  
  /// Native 이벤트 처리
  void _handleNativeEvent(InteractionEvent event) {
    live2dLog.debug(_tag, '이벤트 수신', details: event.type.name);
    
    // 이벤트 스트림에 브로드캐스트
    _eventController.add(event);
    
    // 외부 리스너에게 전달
    for (final listener in _externalListeners) {
      try {
        listener.onInteraction(event);
      } catch (e) {
        live2dLog.error(_tag, '외부 리스너 오류', error: e);
      }
    }
    
    // 자동 반응 처리
    if (_config.autoReactionEnabled) {
      _processAutoReaction(event);
    }
  }
  
  /// 자동 반응 처리
  Future<void> _processAutoReaction(InteractionEvent event) async {
    // 쿨다운 체크
    if (!_checkCooldown(event.type)) {
      live2dLog.debug(_tag, '쿨다운 중', details: event.type.name);
      return;
    }
    
    // 매핑 찾기
    final mapping = _config.getMappingFor(event.type);
    if (mapping == null) {
      live2dLog.debug(_tag, '매핑 없음', details: event.type.name);
      return;
    }
    
    // 조건 평가
    if (mapping.condition != null) {
      final conditionMet = mapping.condition!.evaluate(
        currentModel: _currentModelPath,
      );
      if (!conditionMet) {
        live2dLog.debug(_tag, '조건 미충족', details: event.type.name);
        return;
      }
    }
    
    // 쿨다운 기록
    _recordTrigger(event.type);
    
    // 응답 실행
    await _executeResponse(mapping.response);
  }
  
  /// 쿨다운 체크
  bool _checkCooldown(InteractionType type) {
    final lastTime = _lastTriggerTimes[type];
    if (lastTime == null) return true;
    
    final elapsed = DateTime.now().difference(lastTime).inMilliseconds;
    return elapsed >= _config.globalCooldownMs;
  }
  
  /// 트리거 시간 기록
  void _recordTrigger(InteractionType type) {
    _lastTriggerTimes[type] = DateTime.now();
  }
  
  // ============================================================================
  // 응답 실행
  // ============================================================================
  
  /// 응답 실행
  Future<void> _executeResponse(InteractionResponse response) async {
    live2dLog.debug(_tag, '응답 실행', details: response.toString());
    
    // 지연 처리
    if (response.delayMs > 0) {
      await Future.delayed(Duration(milliseconds: response.delayMs));
    }
    
    switch (response.action) {
      case ResponseAction.playMotion:
        await _executeMotion(response);
        break;
        
      case ResponseAction.setExpression:
        await _executeExpression(response);
        break;
        
      case ResponseAction.randomExpression:
        await _bridge.setRandomExpression();
        break;
        
      case ResponseAction.randomMotion:
        await _executeRandomMotion(response);
        break;
        
      case ResponseAction.vibrate:
        await _executeVibrate(response);
        break;
        
      case ResponseAction.sendSignalToFlutter:
        _emitSignal(response);
        break;
        
      case ResponseAction.composite:
        await _executeComposite(response);
        break;
        
      case ResponseAction.playSound:
      case ResponseAction.showBubble:
        // 미래 구현
        live2dLog.debug(_tag, '미구현 액션', details: response.action.name);
        break;
        
      case ResponseAction.none:
        break;
    }
  }
  
  /// 모션 실행
  Future<void> _executeMotion(InteractionResponse response) async {
    if (response.motionGroup != null) {
      await _bridge.playMotion(
        response.motionGroup!,
        response.motionIndex ?? 0,
        priority: response.motionPriority ?? 2,
      );
    }
  }
  
  /// 표정 실행
  Future<void> _executeExpression(InteractionResponse response) async {
    if (response.expressionId != null) {
      await _bridge.setExpression(response.expressionId!);
    }
  }
  
  /// 랜덤 모션 실행
  Future<void> _executeRandomMotion(InteractionResponse response) async {
    // 특정 그룹에서 랜덤 모션
    final group = response.motionGroup ?? 'idle';
    final count = await _bridge.getMotionCount(group);
    if (count > 0) {
      final randomIndex = DateTime.now().millisecond % count;
      await _bridge.playMotion(group, randomIndex);
    }
  }
  
  /// 진동 실행
  Future<void> _executeVibrate(InteractionResponse response) async {
    // 플랫폼 제약으로 duration 제어가 제한적 (기본 진동만 제공)
    await HapticFeedback.vibrate();
    // 실제 duration 제어는 플랫폼 제약으로 제한적
  }
  
  /// 신호 발행
  void _emitSignal(InteractionResponse response) {
    if (response.signalName != null) {
      final event = InteractionEvent.command(
        response.signalName!,
        params: response.signalData,
      );
      _eventController.add(event);
    }
  }
  
  /// 복합 액션 실행
  Future<void> _executeComposite(InteractionResponse response) async {
    if (response.compositeActions != null) {
      for (final action in response.compositeActions!) {
        await _executeResponse(action);
      }
    }
  }
  
  // ============================================================================
  // 외부 연동 API
  // ============================================================================
  
  /// 외부 리스너 등록
  void addExternalListener(ExternalInteractionListener listener) {
    _externalListeners.add(listener);
    live2dLog.debug(_tag, '외부 리스너 등록', details: '총 ${_externalListeners.length}개');
  }
  
  /// 외부 리스너 제거
  void removeExternalListener(ExternalInteractionListener listener) {
    _externalListeners.remove(listener);
  }
  
  /// 외부에서 감정 트리거
  Future<void> triggerEmotion(String emotion) async {
    live2dLog.info(_tag, '감정 트리거', details: emotion);
    await _bridge.setExpression(emotion);
  }
  
  /// 외부에서 모션 트리거
  Future<void> triggerMotion(String group, {int index = 0, int priority = 2}) async {
    live2dLog.info(_tag, '모션 트리거', details: '$group[$index]');
    await _bridge.playMotion(group, index, priority: priority);
  }
  
  /// 외부에서 표정 트리거
  Future<void> triggerExpression(String expressionId) async {
    live2dLog.info(_tag, '표정 트리거', details: expressionId);
    await _bridge.setExpression(expressionId);
  }
  
  /// 외부 신호 전송
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
    live2dLog.info(_tag, '신호 전송', details: signalName);
    await _bridge.sendSignal(signalName, data: data);
  }
  
  /// AI 말하기 시작
  Future<void> startSpeaking({String? emotion}) async {
    live2dLog.info(_tag, 'AI 말하기 시작', details: emotion);
    if (emotion != null) {
      await triggerExpression(emotion);
    }
    await triggerMotion('talk', priority: 2);
  }
  
  /// AI 말하기 종료
  Future<void> stopSpeaking() async {
    live2dLog.info(_tag, 'AI 말하기 종료');
    await triggerMotion('idle', priority: 1);
  }
  
  /// 알림 반응
  Future<void> reactToNotification({String type = 'default'}) async {
    live2dLog.info(_tag, '알림 반응', details: type);
    
    switch (type) {
      case 'message':
        await triggerExpression('happy');
        await triggerMotion('notice', priority: 2);
        break;
      case 'alert':
        await triggerExpression('surprised');
        await triggerMotion('alert', priority: 3);
        break;
      default:
        await triggerMotion('notice', priority: 2);
    }
  }
}

/// 상호작용 인터페이스 (다른 앱 기능 연동용)
/// 
/// 다른 앱 기능에서 이 인터페이스를 통해 Live2D를 제어할 수 있습니다.
abstract class Live2DInteractionInterface {
  /// 감정 트리거
  Future<void> triggerEmotion(String emotion);
  
  /// 모션 트리거
  Future<void> triggerMotion(String group, int index);
  
  /// 표정 트리거
  Future<void> triggerExpression(String expressionId);
  
  /// 신호 전송
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data});
  
  /// 상호작용 이벤트 스트림
  Stream<InteractionEvent> get interactionStream;
}

/// InteractionManager를 인터페이스로 노출하는 어댑터
class Live2DInteractionAdapter implements Live2DInteractionInterface {
  final InteractionManager _manager;
  
  Live2DInteractionAdapter(this._manager);
  
  @override
  Future<void> triggerEmotion(String emotion) => _manager.triggerEmotion(emotion);
  
  @override
  Future<void> triggerMotion(String group, int index) => 
      _manager.triggerMotion(group, index: index);
  
  @override
  Future<void> triggerExpression(String expressionId) => 
      _manager.triggerExpression(expressionId);
  
  @override
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data}) =>
      _manager.sendSignal(signalName, data: data);
  
  @override
  Stream<InteractionEvent> get interactionStream => _manager.eventStream;
}
